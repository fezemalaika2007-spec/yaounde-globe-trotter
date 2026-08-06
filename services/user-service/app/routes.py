"""user-service/routes.py

Routes:
  POST /register           – Create a new user account
  POST /login              – Authenticate and return a JWT
  GET  /internal/users/<id>/preferences – Internal: fetch user preferences by ID
"""
import uuid
import datetime
import json
import os
import random
import string

import jwt
import requests
from flask import Blueprint, request, jsonify, current_app, g
from werkzeug.security import generate_password_hash, check_password_hash

from app.auth_middleware import token_required
from app.models import (
    get_user_by_username,
    get_user_by_email,
    create_user,
    create_user_with_email,
    create_google_user,
    set_verification_code,
    verify_user,
    get_user_by_id,
    get_favorites_for_user,
    toggle_favorite_for_user,
)

user_bp = Blueprint("user", __name__)


@user_bp.route("/", methods=["GET"])
def health():
    """Health check for the user service."""
    return jsonify({"status": "ok", "service": "user-service"}), 200


# ---------------------------------------------------------------------------
# JWT Helpers
# ---------------------------------------------------------------------------

def create_token(username: str, secret: str) -> str:
    """Return a signed JWT for *username* valid for 24 hours."""
    now = datetime.datetime.now(datetime.timezone.utc)
    payload = {
        "sub": username,
        "iat": now,
        "exp": now + datetime.timedelta(hours=24),
    }
    return jwt.encode(payload, secret, algorithm="HS256")


def decode_token(token: str, secret: str) -> dict:
    """Decode and verify *token*. Raises jwt.PyJWTError on failure."""
    return jwt.decode(token, secret, algorithms=["HS256"])


# ---------------------------------------------------------------------------
# Public routes
# ---------------------------------------------------------------------------

@user_bp.route("/register", methods=["POST"])
def register():
    """Register a new user with email verification.

    Expected JSON body:
        { "username": "alice", "email": "alice@example.com",
          "password": "s3cr3t", "preferences": ["food", "nature"] }

    Creates an unverified user and generates a 6-digit verification code that
    is returned in the response (for local/dev) and would be emailed in
    production. User must call POST /verify to activate their account.

    Returns 201 on success, 400 on validation errors, 409 if exists.
    """
    data = request.get_json(silent=True) or {}
    username = data.get("username", "").strip()
    password = data.get("password", "")
    email = data.get("email", "").strip()
    preferences = data.get("preferences", [])

    if not username or not password or not email:
        return jsonify({"error": "username, email and password are required"}), 400

    if get_user_by_username(username):
        return jsonify({"error": "username already exists"}), 409
    if get_user_by_email(email):
        return jsonify({"error": "email already registered"}), 409

    # Generate a 6-digit verification code.
    verification_code = "".join(random.choices(string.digits, k=6))
    password_hash = generate_password_hash(password)
    user = create_user_with_email(
        username, password_hash, email, preferences,
        verification_code=verification_code,
    )
    # In production, email the code here. For local dev we return it so the
    # flow can be tested end-to-end.
    return jsonify({
        "message": "user registered successfully. Please verify your email.",
        "username": username,
        "email": email,
        "verification_code": verification_code,
        "is_verified": False,
    }), 201


@user_bp.route("/verify", methods=["POST"])
def verify():
    """Verify a user's email address with the code sent at registration.

    Expected JSON body:
        { "username": "alice", "code": "123456" }

    Returns 200 on success, 400 on bad code.
    """
    data = request.get_json(silent=True) or {}
    username = data.get("username", "").strip()
    code = data.get("code", "").strip()

    if not username or not code:
        return jsonify({"error": "username and code are required"}), 400

    if verify_user(username, code):
        return jsonify({"message": "email verified successfully", "username": username}), 200
    return jsonify({"error": "invalid verification code"}), 400


@user_bp.route("/auth/google", methods=["POST"])
def google_auth():
    """Authenticate via a Google ID token.

    Expected JSON body:
        { "id_token": "<google-issued-id-token>" }

    The token is verified against Google's tokeninfo endpoint. If the user
    doesn't exist locally, a new (auto-verified) account is created. Returns
    a JWT on success.
    """
    data = request.get_json(silent=True) or {}
    id_token = data.get("id_token", "").strip()
    if not id_token:
        return jsonify({"error": "id_token is required"}), 400

    # Verify the Google ID token against Google's public endpoint.
    try:
        resp = requests.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": id_token},
            timeout=10,
        )
        if resp.status_code != 200:
            return jsonify({"error": "invalid Google token"}), 401
        info = resp.json()
    except requests.exceptions.RequestException:
        return jsonify({"error": "could not verify Google token"}), 502

    email = info.get("email", "").strip()
    if not email:
        return jsonify({"error": "Google account has no email"}), 400

    # Derive a stable username from the verified email.
    username = email.split("@")[0]

    existing = get_user_by_email(email)
    if existing:
        username = existing["username"]
    else:
        user = create_google_user(username, email, [])
        username = user["username"]

    token = create_token(username, current_app.config["SECRET_KEY"])
    return jsonify({"token": token, "email": email, "username": username}), 200


@user_bp.route("/login", methods=["POST"])
def login():
    """Authenticate a user and return a JWT.

    Expected JSON body:
        { "username": "alice", "password": "s3cr3t" }

    Returns 200 with token on success, 400/401 on failure.
    """
    data = request.get_json(silent=True) or {}
    username = data.get("username", "").strip()
    password = data.get("password", "")

    if not username or not password:
        return jsonify({"error": "username and password are required"}), 400

    user = get_user_by_username(username)
    if not user or not check_password_hash(user["password_hash"], password):
        return jsonify({"error": "invalid credentials"}), 401

    token = create_token(username, current_app.config["SECRET_KEY"])
    return jsonify({"token": token}), 200


@user_bp.route("/favorites", methods=["GET"])
@token_required
def get_favorites():
    username = g.current_user
    favorites = get_favorites_for_user(username)
    return jsonify(favorites), 200


@user_bp.route("/favorites", methods=["POST"])
@token_required
def toggle_favorite():
    username = g.current_user
    data = request.get_json(silent=True) or {}
    destination_name = data.get("destination")
    if not destination_name or not destination_name.strip():
        return jsonify({"error": "destination is required"}), 400
    try:
        favorites = toggle_favorite_for_user(username, destination_name)
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400
    return jsonify(favorites), 200


# ---------------------------------------------------------------------------
# Internal routes (for use by other services ONLY, not exposed through gateway)
# ---------------------------------------------------------------------------

@user_bp.route("/internal/users/preferences", methods=["GET"])
@token_required
def internal_get_preferences_and_favorites():
    """Return the authenticated user's preferences + favorites. Internal use only.

    The Recommendation Service calls this endpoint (with the user's JWT) to
    personalise destination suggestions. This static path takes priority over
    the dynamic ``/internal/users/<user_id>/preferences`` route.
    """
    username = g.current_user
    user = get_user_by_username(username)
    if not user:
        return jsonify({"error": "user not found"}), 404
    try:
        prefs = json.loads(user["preferences"]) if isinstance(user["preferences"], str) else user["preferences"]
    except (json.JSONDecodeError, TypeError):
        prefs = []
    favorites = get_favorites_for_user(username)
    return jsonify({
        "username": username,
        "preferences": prefs,
        "favorites": favorites,
    }), 200


@user_bp.route("/internal/users/<user_id>/preferences", methods=["GET"])
def internal_get_user_preferences(user_id):
    """Return a user's preferences by their UUID. Internal use only."""
    user = get_user_by_id(user_id)
    if not user:
        return jsonify({"error": "user not found"}), 404
    try:
        prefs = json.loads(user["preferences"]) if isinstance(user["preferences"], str) else user["preferences"]
    except (json.JSONDecodeError, TypeError):
        prefs = []
    return jsonify({"user_id": user_id, "username": user["username"], "preferences": prefs}), 200





