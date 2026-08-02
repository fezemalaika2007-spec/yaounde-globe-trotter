"""recommendation-service/routes.py

Routes:
  GET  /destinations                  — List/search destinations (public)
  POST /destinations/<id>/rating      — Submit/update a rating (JWT required)
  GET  /recommendations               — Placeholder recommendations (JWT required)
  POST /sync-destinations             — Trigger Overpass sync (admin)
"""
import json
import logging

from flask import Blueprint, request, jsonify, g, current_app

from app.auth_middleware import token_required
from app.models import (
    get_all_destinations, get_destination_by_id,
    upsert_rating, get_user_rating
)
from app.overpass_sync import sync_destinations as _sync_destinations
from app.overpass_sync import search_overpass as _live_search
from app.recommendations import get_recommendations as _score_recommendations

recommendation_bp = Blueprint("recommendation", __name__)

logger = logging.getLogger(__name__)


@recommendation_bp.route("/", methods=["GET"])
def health():
    """Health check for the recommendation service."""
    return jsonify({"status": "ok", "service": "recommendation-service"}), 200


@recommendation_bp.route("/destinations", methods=["GET"])
def search_destinations():
    """Search destinations by name, tag, and/or max_cost.

    Query parameters (all optional):
        q          – free-text search against name, description
        tag        – filter by a single interest tag (e.g. "food")
        max_cost   – filter by maximum cost (integer, XAF)

    Returns a JSON list of matching destination objects.
    """
    q = request.args.get("q", "").strip().lower()
    tag = request.args.get("tag", "").strip().lower()
    max_cost_str = request.args.get("max_cost", "").strip()

    max_cost = None
    if max_cost_str:
        try:
            max_cost = int(max_cost_str)
        except ValueError:
            return jsonify({"error": "max_cost must be an integer"}), 400

    destinations = get_all_destinations()
    results = []

    for dest in destinations:
        # Free-text filter (name + description)
        if q:
            searchable = " ".join([
                dest.get("name", ""),
                dest.get("description", ""),
                dest.get("area", ""),
            ]).lower()
            if q not in searchable:
                continue

        # Tag filter
        if tag:
            dest_tags = [t.lower() for t in dest.get("tags", [])]
            if tag not in dest_tags:
                continue

        # Cost filter — cost is in XAF (Central African CFA franc)
        if max_cost is not None:
            cost = dest.get("cost")
            if cost is None or cost > max_cost:
                continue

        results.append(dest)

    return jsonify(results), 200


@recommendation_bp.route("/destinations/<dest_id>/rating", methods=["POST"])
@token_required
def submit_rating(dest_id):
    """Submit or update a rating for a destination.

    Expected JSON body:
        { "rating": 4 }

    Rating must be an integer between 1 and 5.
    Returns 200 with updated average_rating and rating_count.
    """
    username = g.current_user

    # Validate destination exists
    destination = get_destination_by_id(dest_id)
    if not destination:
        return jsonify({"error": "destination not found"}), 404

    data = request.get_json(silent=True) or {}
    rating_value = data.get("rating")

    if rating_value is None:
        return jsonify({"error": "rating is required"}), 400

    try:
        rating_value = int(rating_value)
    except (ValueError, TypeError):
        return jsonify({"error": "rating must be an integer"}), 400

    if rating_value < 1 or rating_value > 5:
        return jsonify({"error": "rating must be between 1 and 5"}), 400

    # Use username as user_id for ratings (since JWT sub is username)
    user_id = username

    result = upsert_rating(dest_id, user_id, rating_value)
    return jsonify({
        "message": "rating submitted successfully",
        "average_rating": result["average_rating"],
        "rating_count": result["rating_count"],
    }), 200


@recommendation_bp.route("/recommendations", methods=["GET"])
@token_required
def get_recommendations():
    """Return personalised destination recommendations for the logged-in user.

    Scores all destinations based on:
      - the user's preferences (collected at registration)
      - the user's favorite places
      - popularity (average rating / rating count)
      - content quality (real images, rich descriptions)

    Requires: Authorization: Bearer <token>
    """
    username = g.current_user
    try:
        limit = int(request.args.get("limit", 6))
    except (ValueError, TypeError):
        limit = 6
    limit = max(1, min(limit, 24))

    destinations = get_all_destinations()
    if not destinations:
        return jsonify([]), 200

    auth_token = request.headers.get("Authorization", "").replace("Bearer ", "").strip()
    try:
        recs = _score_recommendations(username, destinations, auth_token, limit=limit)
    except Exception as e:
        logger.exception("Recommendation engine failed, falling back to popular places")
        # Fallback: just return the best-rated/quality destinations.
        recs = sorted(
            destinations,
            key=lambda d: (
                float(d.get("average_rating") or 0.0),
                d.get("rating_count") or 0,
                len((d.get("description") or "").strip()),
            ),
            reverse=True,
        )[:limit]

    return jsonify(recs), 200


@recommendation_bp.route("/search", methods=["GET"])
def live_search_destinations():
    """Live internet search for destinations in Yaoundé via Overpass.

    Query parameter:
        q – the place name to search for (e.g. "museum", "Mfoundi")

    Searches OpenStreetMap for matching places inside the Yaoundé bounding
    box and returns normalized destination objects — this lets the app find
    places that are not yet stored in the local database.

    Returns a JSON list (possibly empty).
    """
    q = request.args.get("q", "").strip()
    if not q:
        return jsonify([]), 200
    try:
        limit = int(request.args.get("limit", 12))
    except (ValueError, TypeError):
        limit = 12
    limit = max(1, min(limit, 24))

    results = _live_search(q, app=current_app._get_current_object(), limit=limit)
    return jsonify(results), 200


@recommendation_bp.route("/sync-destinations", methods=["POST"])
def trigger_sync():
    """Manually trigger an Overpass sync to refresh destination data."""
    try:
        count = _sync_destinations(app=current_app._get_current_object())
        return jsonify({"message": f"Synchronized {count} destinations from Overpass"}), 200
    except Exception as e:
        return jsonify({"error": f"Sync failed: {str(e)}"}), 500
