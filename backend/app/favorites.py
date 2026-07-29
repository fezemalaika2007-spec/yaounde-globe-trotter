"""
app/favorites.py

User favorite destinations.

Routes
------
GET   /favorites  – list the authenticated user's favorite destination names
POST  /favorites  – add or toggle a destination in the user's favorites
DELETE /favorites – remove a destination from the user's favorites

All routes require a valid JWT in the Authorization header.
"""
from flask import Blueprint, request, jsonify, g

from app.auth import token_required
from app.models import get_favorites_for_user, set_favorites_for_user

favorites_bp = Blueprint("favorites", __name__)


@favorites_bp.route("/favorites", methods=["GET"])
@token_required
def list_favorites():
    """List all favorite destination names for the authenticated user.

    Returns 200 with a JSON array of destination name strings.
    Requires: Authorization: Bearer <token>
    """
    username = g.current_user
    favorites = get_favorites_for_user(username)
    return jsonify(favorites), 200


@favorites_bp.route("/favorites", methods=["POST"])
@token_required
def add_favorite():
    """Add a destination to the authenticated user's favorites.

    Expected JSON body:
        { "destination": "Mont Fébé" }

    If the destination is already favorited, it is removed (toggle behavior).

    Returns 200 with the updated favorites list.
    Requires: Authorization: Bearer <token>
    """
    username = g.current_user
    data = request.get_json(silent=True) or {}
    destination = data.get("destination", "").strip()

    if not destination:
        return jsonify({"error": "destination is required"}), 400

    favorites = get_favorites_for_user(username)

    # Toggle behavior: add if not present, remove if already present
    if destination in favorites:
        favorites.remove(destination)
    else:
        favorites.append(destination)

    set_favorites_for_user(username, favorites)
    return jsonify(favorites), 200


@favorites_bp.route("/favorites", methods=["DELETE"])
@token_required
def remove_favorite():
    """Remove a destination from the authenticated user's favorites.

    Expected JSON body:
        { "destination": "Mont Fébé" }

    Returns 200 with the updated favorites list.
    Requires: Authorization: Bearer <token>
    """
    username = g.current_user
    data = request.get_json(silent=True) or {}
    destination = data.get("destination", "").strip()

    if not destination:
        return jsonify({"error": "destination is required"}), 400

    favorites = get_favorites_for_user(username)
    if destination in favorites:
        favorites.remove(destination)
        set_favorites_for_user(username, favorites)

    return jsonify(favorites), 200