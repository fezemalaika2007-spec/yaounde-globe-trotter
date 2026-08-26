"""recommendation-service/auth_middleware.py

Reusable JWT validation middleware for the Recommendation Service.
Uses the same SECRET_KEY as the User Service to validate tokens.
"""
from functools import wraps
import jwt
from flask import request, jsonify, current_app, g


def token_required(f):
    """Decorator to protect endpoints with JWT authorization.
    Sets g.current_user to the authenticated username.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        username = _get_current_user()
        if not username:
            return jsonify({"error": "authentication required"}), 401
        g.current_user = username
        return f(*args, **kwargs)
    return decorated


def _get_current_user():
    """Extract and validate the JWT from the Authorization header.
    Returns the username (subject claim) or None if invalid.
    """
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None
    token = auth_header.split(" ", 1)[1]
    try:
        payload = jwt.decode(token, current_app.config["SECRET_KEY"], algorithms=["HS256"])
        return payload.get("sub")
    except jwt.PyJWTError:
        return None
