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
from app.email_utils import send_email
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
    get_user_by_username_or_email,
    set_reset_code,
    verify_reset_code_and_update_password,
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
    """Register a new user with email verification."""
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

    send_email(
        to_email=email,
        subject="Yaounde.Trip — Verify Your Email",
        body_text=(
            f"Hello {username},\n\n"
            f"Thank you for registering with Yaounde.Trip!\n\n"
            f"Your 6-digit email verification code is: {verification_code}\n\n"
            f"Please enter this code in the app to activate your account and start exploring.\n\n"
            f"Happy travels,\nThe Yaounde.Trip Team"
        ),
    )

# In dev mode (no SMTP configured) the code is only printed to the logs,
    # so include it in the response for the app to show the user directly.
    smtp_configured = bool(
        os.environ.get("SMTP_SERVER", "").strip()
        and os.environ.get("SMTP_USERNAME", "").strip()
        and os.environ.get("SMTP_PASSWORD", "").strip()
    )
    response = {
        "message": "user registered successfully. Please verify your email.",
        "username": username,
        "email": email,
        "is_verified": False,
    }
    if not smtp_configured:
        response["verification_code"] = verification_code

    return jsonify(response), 201


@user_bp.route("/verify", methods=["POST"])
def verify():
    """Verify a user's email address with the code sent at registration."""
    data = request.get_json(silent=True) or {}
    username = data.get("username", "").strip()
    code = data.get("code", "").strip()

    if not username or not code:
        return jsonify({"error": "username and code are required"}), 400

    if verify_user(username, code):
        return jsonify({"message": "email verified successfully", "username": username}), 200
    return jsonify({"error": "invalid verification code"}), 400


@user_bp.route("/resend-code", methods=["POST"])
def resend_code():
    """Resend a 6-digit verification code to the user's email."""
    data = request.get_json(silent=True) or {}
    identifier = data.get("username", "").strip() or data.get("email", "").strip()
    if not identifier:
        return jsonify({"error": "username or email is required"}), 400

    user = get_user_by_username_or_email(identifier)
    if not user:
        return jsonify({"error": "user not found"}), 404
    if user.get("is_verified"):
        return jsonify({"message": "user is already verified"}), 200

    verification_code = "".join(random.choices(string.digits, k=6))
    set_verification_code(user["username"], verification_code)

    send_email(
        to_email=user["email"],
        subject="Yaounde.Trip — New Email Verification Code",
        body_text=(
            f"Hello {user['username']},\n\n"
            f"Your new 6-digit email verification code is: {verification_code}\n\n"
            f"Please enter this code in the app to activate your account."
        ),
    )
# In dev mode (no SMTP) the code is only in the logs; expose it to the app.
    smtp_configured = bool(
        os.environ.get("SMTP_SERVER", "").strip()
        and os.environ.get("SMTP_USERNAME", "").strip()
        and os.environ.get("SMTP_PASSWORD", "").strip()
    )
    response = {
        "message": "Verification code sent to your email.",
        "username": user["username"],
    }
    if not smtp_configured:
        response["verification_code"] = verification_code
    return jsonify(response), 200


@user_bp.route("/forgot-password", methods=["POST"])
def forgot_password():
    """Send a password reset code to the user's registered email."""
    data = request.get_json(silent=True) or {}
    identifier = data.get("email", "").strip() or data.get("username", "").strip()
    if not identifier:
        return jsonify({"error": "username or email is required"}), 400

    user = get_user_by_username_or_email(identifier)
    if not user:
        return jsonify({
            "message": "If an account exists with that username or email, a reset code has been sent to your email."
        }), 200

    reset_code = "".join(random.choices(string.digits, k=6))
    expires_at = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=1)
    set_reset_code(user["username"], reset_code, expires_at.isoformat())

    send_email(
        to_email=user["email"],
        subject="Yaounde.Trip — Password Reset Code",
        body_text=(
            f"Hello {user['username']},\n\n"
            f"We received a request to reset your password for Yaounde.Trip.\n\n"
            f"Your 6-digit password reset code is: {reset_code}\n\n"
            f"This code will expire in 1 hour. If you did not request a password reset, please ignore this email."
        ),
    )
    return jsonify({
        "message": "If an account exists with that username or email, a reset code has been sent to your email."
    }), 200


@user_bp.route("/reset-password", methods=["POST"])
def reset_password():
    """Reset user password using the verification code sent to their email."""
    data = request.get_json(silent=True) or {}
    identifier = data.get("username", "").strip() or data.get("email", "").strip()
    code = data.get("code", "").strip()
    new_password = data.get("password", "")

    if not identifier or not code or not new_password:
        return jsonify({"error": "username/email, reset code, and new password are required"}), 400

    password_hash = generate_password_hash(new_password)
    if verify_reset_code_and_update_password(identifier, code, password_hash):
        return jsonify({"message": "Password reset successfully. You can now log in with your new password."}), 200

    return jsonify({"error": "Invalid or expired password reset code"}), 400


@user_bp.route("/auth/google", methods=["POST"])
def google_auth():
    """Authenticate via a Google ID token or Access token.

    Expected JSON body:
        { "id_token": "<google-issued-id-token>", "access_token": "<google-access-token>" }

    The token is verified against Google's tokeninfo or userinfo endpoint. If the
    user doesn't exist locally, a new (auto-verified) account is created. Returns
    a JWT on success.
    """
    data = request.get_json(silent=True) or {}
    id_token = data.get("id_token", "").strip()
    access_token = data.get("access_token", "").strip()

    if not id_token and not access_token:
        return jsonify({"error": "id_token or access_token is required"}), 400

    email = None

    # Option 1: Try verifying ID token via tokeninfo
    if id_token:
        try:
            resp = requests.get(
                "https://oauth2.googleapis.com/tokeninfo",
                params={"id_token": id_token},
                timeout=10,
            )
            if resp.status_code == 200:
                info = resp.json()
                email = info.get("email", "").strip()
        except requests.exceptions.RequestException:
            pass

    # Option 2: Try verifying Access token via userinfo
    if not email and access_token:
        try:
            resp = requests.get(
                "https://www.googleapis.com/oauth2/v3/userinfo",
                headers={"Authorization": f"Bearer {access_token}"},
                timeout=10,
            )
            if resp.status_code == 200:
                info = resp.json()
                email = info.get("email", "").strip()
        except requests.exceptions.RequestException:
            pass

    if not email:
        return jsonify({"error": "Could not verify Google token with Google servers"}), 401

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

    Returns 200 with token on success, 400/401/403 on failure.
    """
    data = request.get_json(silent=True) or {}
    username = data.get("username", "").strip()
    password = data.get("password", "")

    if not username or not password:
        return jsonify({"error": "username and password are required"}), 400

    user = get_user_by_username_or_email(username)
    if not user or not check_password_hash(user["password_hash"], password):
        return jsonify({"error": "invalid credentials"}), 401

    if not user.get("is_verified", False):
        return jsonify({
            "error": "Please verify your email address before logging in.",
            "is_verified": False,
            "username": user["username"],
        }), 403

    token = create_token(user["username"], current_app.config["SECRET_KEY"])
    return jsonify({"token": token, "username": user["username"]}), 200


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
