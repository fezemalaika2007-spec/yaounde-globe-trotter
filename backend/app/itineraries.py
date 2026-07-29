"""
app/itineraries.py

Create and list itineraries for the authenticated user.

Routes
------
POST /itineraries – create a new itinerary
GET  /itineraries – list all itineraries for the logged-in user

Both routes require a valid JWT in the Authorization header.
"""
import uuid
import datetime

from flask import Blueprint, request, jsonify, g

from app.auth import token_required
from app.models import get_itineraries_for_user, save_itinerary

itineraries_bp = Blueprint("itineraries", __name__)


@itineraries_bp.route("/itineraries", methods=["POST"])
@token_required
def create_itinerary():
    """Create a new itinerary for the authenticated user.

    Expected JSON body:
        {
          "title": "Summer in Europe",
          "destinations": ["Paris", "Rome"],
          "start_date": "2025-06-01",
          "end_date": "2025-06-15",
          "notes": "Optional free-text notes"
        }

    Returns 201 with the created itinerary on success.
    Requires: Authorization: ******
    """
    username = g.current_user

    data = request.get_json(silent=True) or {}
    title = data.get("title", "")
    if isinstance(title, str):
        title = title.strip()
    destinations = data.get("destinations")
    start_date = data.get("start_date")
    end_date = data.get("end_date")

    if not title:
        return jsonify({"error": "title is required"}), 400

    if not destinations or not isinstance(destinations, list):
        return jsonify({"error": "destinations must be a non-empty list"}), 400

    if not start_date or not isinstance(start_date, str) or not start_date.strip():
        return jsonify({"error": "start_date is required"}), 400

    if not end_date or not isinstance(end_date, str) or not end_date.strip():
        return jsonify({"error": "end_date is required"}), 400

    itinerary = {
        "id": str(uuid.uuid4()),
        "username": username,
        "title": title,
        "destinations": destinations,
        "start_date": start_date.strip(),
        "end_date": end_date.strip(),
        "notes": data.get("notes", ""),
        "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    save_itinerary(itinerary)
    return jsonify(itinerary), 201


@itineraries_bp.route("/itineraries", methods=["GET"])
@token_required
def list_itineraries():
    """List all itineraries for the authenticated user.

    Returns 200 with a JSON array of itinerary objects.
    Requires: Authorization: ******
    """
    username = g.current_user
    itineraries = get_itineraries_for_user(username)
    return jsonify(itineraries), 200
