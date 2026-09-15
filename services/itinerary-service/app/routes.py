"""itinerary-service/routes.py

Routes:
  POST   /itineraries                 — Create a new itinerary (JWT required)
  GET    /itineraries                 — List all itineraries for the logged-in user (JWT required)
  PUT    /itineraries/<itinerary_id>  — Update an itinerary (JWT required)
  DELETE /itineraries/<itinerary_id>  — Delete an itinerary (JWT required)
  GET    /internal/users/<user_id>/itineraries — Internal: get past itineraries by user ID
"""
import json

from flask import Blueprint, request, jsonify, g

from app.auth_middleware import token_required
from app.models import (
    get_itineraries_for_user, get_itineraries_by_user_id, create_itinerary,
    get_itinerary_by_id, update_itinerary, delete_itinerary
)

itinerary_bp = Blueprint("itinerary", __name__)


@itinerary_bp.route("/", methods=["GET"])
def health():
    """Health check for the itinerary service."""
    return jsonify({"status": "ok", "service": "itinerary-service"}), 200


@itinerary_bp.route("/itineraries", methods=["POST"])
@token_required
def create_itinerary_route():
    """Create a new itinerary for the authenticated user."""
    username = g.current_user
    user_id = username  # Enforce user_id from JWT context
    data = request.get_json(silent=True) or {}
    title = data.get("title", "").strip() if data.get("title") else ""
    destinations = data.get("destinations")
    start_date = data.get("start_date")
    end_date = data.get("end_date")
    notes = data.get("notes", "")

    if not title:
        return jsonify({"error": "title is required"}), 400
    if not destinations or not isinstance(destinations, list):
        return jsonify({"error": "destinations must be a non-empty list"}), 400
    if not start_date or not isinstance(start_date, str) or not start_date.strip():
        return jsonify({"error": "start_date is required"}), 400
    if not end_date or not isinstance(end_date, str) or not end_date.strip():
        return jsonify({"error": "end_date is required"}), 400

    itinerary = create_itinerary(
        username=username,
        user_id=user_id,
        title=title,
        destinations=destinations,
        start_date=start_date.strip(),
        end_date=end_date.strip(),
        notes=notes,
    )
    return jsonify(itinerary), 201


@itinerary_bp.route("/itineraries", methods=["GET"])
@token_required
def list_itineraries():
    """List all itineraries for the authenticated user."""
    username = g.current_user
    itineraries = get_itineraries_for_user(username)
    return jsonify(itineraries), 200


@itinerary_bp.route("/itineraries/<itinerary_id>", methods=["PUT"])
@token_required
def update_itinerary_route(itinerary_id):
    """Update an existing itinerary for the authenticated user."""
    username = g.current_user
    data = request.get_json(silent=True) or {}
    title = data.get("title")
    destinations = data.get("destinations")
    start_date = data.get("start_date")
    end_date = data.get("end_date")
    notes = data.get("notes")

    updated = update_itinerary(
        itinerary_id=itinerary_id,
        username=username,
        title=title,
        destinations=destinations,
        start_date=start_date,
        end_date=end_date,
        notes=notes,
    )
    if not updated:
        return jsonify({"error": "itinerary not found or access denied"}), 404
    return jsonify(updated), 200


@itinerary_bp.route("/itineraries/<itinerary_id>", methods=["DELETE"])
@token_required
def delete_itinerary_route(itinerary_id):
    """Delete an itinerary for the authenticated user."""
    username = g.current_user
    success = delete_itinerary(itinerary_id, username)
    if not success:
        return jsonify({"error": "itinerary not found or access denied"}), 404
    return jsonify({"message": "itinerary deleted successfully"}), 200


@itinerary_bp.route("/internal/users/<user_id>/itineraries", methods=["GET"])
def internal_get_user_itineraries(user_id):
    """Return past itineraries for a user by their UUID. Internal use only."""
    itineraries = get_itineraries_by_user_id(user_id)
    return jsonify(itineraries), 200
