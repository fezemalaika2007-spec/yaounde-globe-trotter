"""recommendation-service/routes.py

Routes:
  GET  /destinations                  — List/search destinations (public)
  POST /destinations/<id>/rating      — Submit/update a rating (JWT required)
  GET  /destinations/<id>/user-rating — Get user's own rating (JWT required)
  GET  /destinations/<id>/comments    — List comments for a destination
  POST /destinations/<id>/comments    — Add a comment (JWT required)
  DELETE /destinations/<id>/comments/<cid> — Delete own comment (JWT required)
  GET  /notifications                 — List notifications (JWT required)
  POST /notifications/<id>/read       — Mark notification read (JWT required)
  POST /notifications/read-all        — Mark all read (JWT required)
  POST /feedback                      — Submit feedback (JWT required)
  GET  /feedback                      — List all feedback (admin only)
  POST /feedback/<id>/resolve         — Resolve feedback (admin only)
  GET  /recommendations               — Categorized recommendations (JWT required)
  POST /reseed                        — Reseed authentic Yaoundé destinations
"""
import json
import logging
import urllib.parse
import urllib.request

from flask import Blueprint, request, jsonify, g, current_app, Response

from app.auth_middleware import token_required
from app.models import (
    get_all_destinations, get_destination_by_id,
    upsert_rating, get_user_rating,
    create_notification, get_notifications_for_user,
    get_unread_notification_count, mark_notification_read,
    mark_all_notifications_read,
    create_comment, get_comments_for_destination, delete_comment,
    create_feedback, get_all_feedback, mark_feedback_resolved,
    ADMIN_USERNAME,
)
from app.recommendations import get_sectioned_recommendations as _section_recommendations

recommendation_bp = Blueprint("recommendation", __name__)

logger = logging.getLogger(__name__)


@recommendation_bp.route("/", methods=["GET"])
def health():
    """Health check for the recommendation service."""
    return jsonify({"status": "ok", "service": "recommendation-service"}), 200


# ---------------------------------------------------------------------------
# Destinations
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Ratings
# ---------------------------------------------------------------------------

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

    # Auto-create notification
    stars = "★" * rating_value + "☆" * (5 - rating_value)
    dest_name = destination.get("name", "a destination")
    try:
        create_notification(
            user_id=user_id,
            title="Rating Submitted",
            message=f"You rated {dest_name} {stars} ({rating_value}/5)",
            notif_type="rating",
            related_id=dest_id,
        )
    except Exception as e:
        logger.warning(f"Failed to create rating notification: {e}")

    return jsonify({
        "message": "rating submitted successfully",
        "average_rating": result["average_rating"],
        "rating_count": result["rating_count"],
    }), 200


@recommendation_bp.route("/destinations/<dest_id>/user-rating", methods=["GET"])
@token_required
def get_user_rating_route(dest_id):
    """Get the current user's rating for a destination."""
    username = g.current_user
    destination = get_destination_by_id(dest_id)
    if not destination:
        return jsonify({"error": "destination not found"}), 404

    rating = get_user_rating(dest_id, username)
    return jsonify({"rating": rating}), 200


# ---------------------------------------------------------------------------
# Comments
# ---------------------------------------------------------------------------

@recommendation_bp.route("/destinations/<dest_id>/comments", methods=["GET"])
def get_comments(dest_id):
    """List all comments for a destination (public)."""
    destination = get_destination_by_id(dest_id)
    if not destination:
        return jsonify({"error": "destination not found"}), 404

    comments = get_comments_for_destination(dest_id)
    return jsonify(comments), 200


@recommendation_bp.route("/destinations/<dest_id>/comments", methods=["POST"])
@token_required
def post_comment(dest_id):
    """Add a comment to a destination (JWT required)."""
    username = g.current_user
    destination = get_destination_by_id(dest_id)
    if not destination:
        import urllib.parse
        clean_id = urllib.parse.unquote(dest_id)
        destination = get_destination_by_id(clean_id)

    if not destination:
        all_d = get_all_destinations()
        for d in all_d:
            if d.get("name", "").lower() == dest_id.lower() or d.get("id") == dest_id:
                destination = d
                dest_id = d["id"]
                break

    data = request.get_json(silent=True) or {}
    text = (data.get("text") or "").strip()
    if not text:
        return jsonify({"error": "text is required"}), 400
    if len(text) > 2000:
        return jsonify({"error": "comment too long (max 2000 characters)"}), 400

    comment = create_comment(dest_id, username, username, text)
    return jsonify(comment), 201



@recommendation_bp.route("/destinations/<dest_id>/comments/<comment_id>", methods=["DELETE"])
@token_required
def remove_comment(dest_id, comment_id):
    """Delete a comment (only the author can delete)."""
    username = g.current_user
    success = delete_comment(comment_id, username)
    if not success:
        return jsonify({"error": "comment not found or access denied"}), 404
    return jsonify({"message": "comment deleted"}), 200


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

@recommendation_bp.route("/notifications", methods=["GET"])
@token_required
def list_notifications():
    """List notifications for the current user."""
    username = g.current_user
    notifications = get_notifications_for_user(username)
    unread = get_unread_notification_count(username)
    return jsonify({"notifications": notifications, "unread_count": unread}), 200


@recommendation_bp.route("/notifications/<notif_id>/read", methods=["POST"])
@token_required
def read_notification(notif_id):
    """Mark a single notification as read."""
    username = g.current_user
    mark_notification_read(notif_id, username)
    return jsonify({"message": "notification marked as read"}), 200


@recommendation_bp.route("/notifications/read-all", methods=["POST"])
@token_required
def read_all_notifications():
    """Mark all notifications as read for the current user."""
    username = g.current_user
    mark_all_notifications_read(username)
    return jsonify({"message": "all notifications marked as read"}), 200


# ---------------------------------------------------------------------------
# Feedback
# ---------------------------------------------------------------------------

@recommendation_bp.route("/feedback", methods=["POST"])
@token_required
def submit_feedback():
    """Submit feedback or a bug report."""
    username = g.current_user
    data = request.get_json(silent=True) or {}

    category = (data.get("category") or "feedback").strip()
    if category not in ("bug", "feedback", "suggestion"):
        category = "feedback"

    subject = (data.get("subject") or "").strip()
    message = (data.get("message") or "").strip()

    if not subject:
        return jsonify({"error": "subject is required"}), 400
    if not message:
        return jsonify({"error": "message is required"}), 400

    result = create_feedback(username, username, category, subject, message)

    # Notify admin
    try:
        create_notification(
            user_id=ADMIN_USERNAME,
            title="New Feedback",
            message=f"{username} submitted a {category}: {subject}",
            notif_type="feedback",
            related_id=result["id"],
        )
    except Exception as e:
        logger.warning(f"Failed to create feedback notification: {e}")

    return jsonify({"message": "feedback submitted successfully", "feedback": result}), 201


@recommendation_bp.route("/feedback", methods=["GET"])
@token_required
def list_feedback():
    """List all feedback (admin only)."""
    username = g.current_user
    if username != ADMIN_USERNAME:
        return jsonify({"error": "access denied"}), 403

    feedback_list = get_all_feedback()
    return jsonify(feedback_list), 200


@recommendation_bp.route("/feedback/<feedback_id>/resolve", methods=["POST"])
@token_required
def resolve_feedback(feedback_id):
    """Mark feedback as resolved (admin only)."""
    username = g.current_user
    if username != ADMIN_USERNAME:
        return jsonify({"error": "access denied"}), 403

    mark_feedback_resolved(feedback_id)
    return jsonify({"message": "feedback marked as resolved"}), 200


# ---------------------------------------------------------------------------
# Recommendations
# ---------------------------------------------------------------------------

@recommendation_bp.route("/recommendations", methods=["GET"])
@token_required
def get_recommendations():
    """Return categorized destination recommendations for the logged-in user.

    Returns a structured, categorized response:

        {
          "most_popular": [destination, ...],   // highest rating_count
          "highly_rated": [destination, ...],   // highest average_rating (min count)
          "recently_added": [destination, ...], // most recently synced
          "less_costly": [destination, ...],    // lowest known cost (XAF)
          "food_markets": [destination, ...],   // extra: popular food/market tag
          "nature_parks": [destination, ...],   // extra: popular nature tag
          "sections": [ ... ],                  // backward-compat flat sections
          "recommendations": [destination, ...] // flat list for backward compat
        }

    Requires: Authorization: Bearer <token>
    """
    try:
        limit = int(request.args.get("limit", 5))
    except (ValueError, TypeError):
        limit = 5
    limit = max(1, min(limit, 24))

    destinations = get_all_destinations()
    if not destinations:
        return jsonify({
            "most_popular": [], "highly_rated": [], "recently_added": [],
            "less_costly": [], "sections": [], "recommendations": []
        }), 200

    auth_token = request.headers.get("Authorization", "").replace("Bearer ", "").strip()
    payload = _section_recommendations(destinations, token=auth_token, limit=limit)

    # Flatten all section items into a single recommendations list for
    # backward compatibility with clients that expect a plain list.
    flat = []
    seen = set()
    for section in payload.get("sections", []):
        for item in section.get("items", []):
            key = item.get("id") or item.get("name") or ""
            if key and key in seen:
                continue
            if key:
                seen.add(key)
            flat.append(item)

    payload["recommendations"] = flat
    return jsonify(payload), 200


# ---------------------------------------------------------------------------
# Import / Proxy helpers
# ---------------------------------------------------------------------------

@recommendation_bp.route("/import-urls", methods=["POST"])
def import_urls():
    """Accept a JSON payload with a list of URLs and import destination metadata for each."""
    data = request.get_json(silent=True) or {}
    urls = data.get("urls", [])
    if isinstance(urls, str):
        urls = [urls]

    imported_ids = []
    from app.import_utils import extract_metadata_from_url, save_destination_from_dict

    for url in urls:
        if not url or not isinstance(url, str):
            continue
        try:
            meta = extract_metadata_from_url(url)
            dest_id = save_destination_from_dict(meta, app=current_app._get_current_object())
            imported_ids.append(dest_id)
        except Exception as e:
            logger.warning(f"Failed to import URL '{url}': {e}")


@recommendation_bp.route("/api/image-proxy", methods=["GET"])
def proxy_image():
    """Proxy external image requests (like Google CDN) to resolve CORS issues on web."""
    image_url = request.args.get("url", "").strip()
    if not image_url or not image_url.startswith("http"):
        return jsonify({"error": "Invalid URL"}), 400

    try:
        req = urllib.request.Request(
            image_url,
            headers={
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
            }
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            content_type = resp.headers.get("Content-Type", "image/jpeg")
            image_data = resp.read()
            return Response(
                image_data,
                mimetype=content_type,
                headers={
                    "Access-Control-Allow-Origin": "*",
                    "Cache-Control": "public, max-age=86400"
                }
            )
    except Exception as e:
        logger.warning(f"Image proxy failed for {image_url}: {e}")
        return jsonify({"error": str(e)}), 500
