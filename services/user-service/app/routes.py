"""user-service/routes.py

Routes:
  POST /register           – Create a new user account
  POST /login              – Authenticate and return a JWT
  GET  /internal/users/<id>/preferences – Internal: fetch user preferences by ID
"""
import uuid
import datetime
import json

import jwt
from flask import Blueprint, request, jsonify, current_app, g
from werkzeug.security import generate_password_hash, check_password_hash

from app.auth_middleware import token_required
from app.models import (
    get_user_by_username,
    create_user,
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
    """Register a new user.

    Expected JSON body:
        { "username": "alice", "password": "s3cr3t", "preferences": ["food", "nature"] }

    Returns 201 on success, 400 on validation errors, 409 if username exists.
    """
    data = request.get_json(silent=True) or {}
    username = data.get("username", "").strip()
    password = data.get("password", "")
    preferences = data.get("preferences", [])

    if not username or not password:
        return jsonify({"error": "username and password are required"}), 400

    if get_user_by_username(username):
        return jsonify({"error": "username already exists"}), 409

    password_hash = generate_password_hash(password)
    user = create_user(username, password_hash, preferences)
    return jsonify({"message": "user registered successfully", "username": username}), 201


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

