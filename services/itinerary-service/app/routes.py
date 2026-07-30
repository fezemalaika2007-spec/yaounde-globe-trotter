"""itinerary-service/routes.py

Routes:
  POST /itineraries — Create a new itinerary (JWT required)
  GET  /itineraries — List all itineraries for the logged-in user (JWT required)
  GET  /internal/users/<user_id>/itineraries — Internal: get past itineraries by user ID
"""
import uuid
import datetime
import json

from flask import Blueprint, request, jsonify, g

from app.auth_middleware import token_required
from app.models import get_itineraries_for_user, get_itineraries_by_user_id, create_itinerary

itinerary_bp = Blueprint("itinerary", __name__)


@itinerary_bp.route("/itineraries", methods=["POST"])
@token_required
def create_itinerary_route():
    """Create a new itinerary for the authenticated user.

    Expected JSON body:
        {
          "title": "Summer in Yaoundé",
          "destinations": ["Mont Fébé", "Mefou National Park"],
          "start_date": "2025-06-01",
          "end_date": "2025-06-15",
          "notes": "Optional notes"
        }

    Returns 201 with the created itinerary.
    """
    username = g.current_user
    data = request.get_json(silent=True) or {}
    user_id = data.get("user_id", username)
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
    # Parse destinations JSON string back to list
    for it in itineraries:
        if isinstance(it.get("destinations"), str):
            try:
                it["destinations"] = json.loads(it["destinations"])
            except (json.JSONDecodeError, TypeError):
                it["destinations"] = []
    return jsonify(itineraries), 200


@itinerary_bp.route("/internal/users/<user_id>/itineraries", methods=["GET"])
def internal_get_user_itineraries(user_id):
    """Return past itineraries for a user by their UUID. Internal use only."""
    itineraries = get_itineraries_by_user_id(user_id)
    for it in itineraries:
        if isinstance(it.get("destinations"), str):
            try:
                it["destinations"] = json.loads(it["destinations"])
            except (json.JSONDecodeError, TypeError):
                it["destinations"] = []
    return jsonify(itineraries), 200
