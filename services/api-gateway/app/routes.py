"""
api-gateway/app/routes.py

Proxy routes — forwards each request to the correct backend microservice.
Contains no business logic, only routing/forwarding.
"""

import os

import requests
from flask import Blueprint, request, jsonify, Response

gateway_bp = Blueprint("gateway", __name__)

# Service URLs from environment variables (set in docker-compose.yml)
USER_SERVICE_URL = os.environ.get("USER_SERVICE_URL", "http://user-service:5001")
ITINERARY_SERVICE_URL = os.environ.get("ITINERARY_SERVICE_URL", "http://itinerary-service:5002")
RECOMMENDATION_SERVICE_URL = os.environ.get("RECOMMENDATION_SERVICE_URL", "http://recommendation-service:5003")


def _proxy(method: str, target_url: str) -> Response:
    """Forward a request to the target service and return its response."""
    # Handle CORS OPTIONS preflight requests directly
    if request.method == "OPTIONS":
        resp = Response("", status=200)
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        resp.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
        return resp

    headers = {
        "Content-Type": "application/json",
    }
    # Pass through Authorization header
    auth = request.headers.get("Authorization")
    if auth:
        headers["Authorization"] = auth

    # Forward query parameters
    params = dict(request.args)

    actual_method = request.method if method == "DYNAMIC" else method

    try:
        resp = requests.request(
            method=actual_method,
            url=target_url,
            headers=headers,
            params=params if params else None,
            json=request.get_json(silent=True) or None,
            timeout=30,
        )
        # Return the backend service's response as-is with CORS headers
        res = Response(
            response=resp.content,
            status=resp.status_code,
            content_type=resp.headers.get("Content-Type", "application/json"),
        )
        res.headers["Access-Control-Allow-Origin"] = "*"
        return res
    except requests.exceptions.ConnectionError:
        return jsonify({"error": "service unavailable"}), 503
    except requests.exceptions.Timeout:
        return jsonify({"error": "service timeout"}), 504


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

@gateway_bp.route("/health", methods=["GET", "OPTIONS"])
def health():
    """Check all backend services are reachable."""
    if request.method == "OPTIONS":
        return _proxy("OPTIONS", "")
    services = {
        "user-service": USER_SERVICE_URL,
        "itinerary-service": ITINERARY_SERVICE_URL,
        "recommendation-service": RECOMMENDATION_SERVICE_URL,
    }
    statuses = {}
    all_ok = True
    for name, url in services.items():
        try:
            r = requests.get(url, timeout=5)
            statuses[name] = "ok" if r.ok else f"error {r.status_code}"
            if not r.ok:
                all_ok = False
        except requests.exceptions.RequestException as e:
            statuses[name] = f"unreachable: {str(e)}"
            all_ok = False
    overall = "ok" if all_ok else "degraded"
    return jsonify({"status": overall, "services": statuses}), 200 if all_ok else 503


# ---------------------------------------------------------------------------
# Auth routes → User Service
# ---------------------------------------------------------------------------

@gateway_bp.route("/register", methods=["POST", "OPTIONS"])
def register():
    return _proxy("POST", f"{USER_SERVICE_URL}/register")


@gateway_bp.route("/login", methods=["POST", "OPTIONS"])
def login():
    return _proxy("POST", f"{USER_SERVICE_URL}/login")


@gateway_bp.route("/verify", methods=["POST", "OPTIONS"])
def verify():
    return _proxy("POST", f"{USER_SERVICE_URL}/verify")


@gateway_bp.route("/resend-code", methods=["POST", "OPTIONS"])
def resend_code():
    return _proxy("POST", f"{USER_SERVICE_URL}/resend-code")


@gateway_bp.route("/forgot-password", methods=["POST", "OPTIONS"])
def forgot_password():
    return _proxy("POST", f"{USER_SERVICE_URL}/forgot-password")


@gateway_bp.route("/reset-password", methods=["POST", "OPTIONS"])
def reset_password():
    return _proxy("POST", f"{USER_SERVICE_URL}/reset-password")


@gateway_bp.route("/auth/google", methods=["POST", "OPTIONS"])
def google_auth():
    return _proxy("POST", f"{USER_SERVICE_URL}/auth/google")


# ---------------------------------------------------------------------------
# Destination & Recommendation routes → Recommendation Service
# ---------------------------------------------------------------------------

@gateway_bp.route("/destinations", methods=["GET", "OPTIONS"])
def get_destinations():
    return _proxy("GET", f"{RECOMMENDATION_SERVICE_URL}/destinations")


@gateway_bp.route("/destinations/<dest_id>/rating", methods=["POST", "OPTIONS"])
def submit_rating(dest_id):
    return _proxy("POST", f"{RECOMMENDATION_SERVICE_URL}/destinations/{dest_id}/rating")


@gateway_bp.route("/destinations/<dest_id>/user-rating", methods=["GET", "OPTIONS"])
def get_user_rating(dest_id):
    return _proxy("GET", f"{RECOMMENDATION_SERVICE_URL}/destinations/{dest_id}/user-rating")


@gateway_bp.route("/recommendations", methods=["GET", "OPTIONS"])
def get_recommendations():
    return _proxy("GET", f"{RECOMMENDATION_SERVICE_URL}/recommendations")


@gateway_bp.route("/favorites", methods=["GET", "POST", "OPTIONS"])
def favorites():
    return _proxy("DYNAMIC", f"{USER_SERVICE_URL}/favorites")


@gateway_bp.route("/import-urls", methods=["POST", "OPTIONS"])
def import_urls():
    return _proxy("POST", f"{RECOMMENDATION_SERVICE_URL}/import-urls")


@gateway_bp.route("/api/image-proxy", methods=["GET", "OPTIONS"])
def image_proxy():
    return _proxy("GET", f"{RECOMMENDATION_SERVICE_URL}/api/image-proxy")


# ---------------------------------------------------------------------------
# Comment routes → Recommendation Service
# ---------------------------------------------------------------------------

@gateway_bp.route("/destinations/<dest_id>/comments", methods=["GET", "POST", "OPTIONS"])
def destination_comments(dest_id):
    return _proxy("DYNAMIC", f"{RECOMMENDATION_SERVICE_URL}/destinations/{dest_id}/comments")


@gateway_bp.route("/destinations/<dest_id>/comments/<comment_id>", methods=["DELETE", "OPTIONS"])
def delete_destination_comment(dest_id, comment_id):
    return _proxy("DELETE", f"{RECOMMENDATION_SERVICE_URL}/destinations/{dest_id}/comments/{comment_id}")


# ---------------------------------------------------------------------------
# Notification routes → Recommendation Service
# ---------------------------------------------------------------------------

@gateway_bp.route("/notifications", methods=["GET", "OPTIONS"])
def list_notifications():
    return _proxy("GET", f"{RECOMMENDATION_SERVICE_URL}/notifications")


@gateway_bp.route("/notifications/<notif_id>/read", methods=["POST", "OPTIONS"])
def read_notification(notif_id):
    return _proxy("POST", f"{RECOMMENDATION_SERVICE_URL}/notifications/{notif_id}/read")


@gateway_bp.route("/notifications/read-all", methods=["POST", "OPTIONS"])
def read_all_notifications():
    return _proxy("POST", f"{RECOMMENDATION_SERVICE_URL}/notifications/read-all")


# ---------------------------------------------------------------------------
# Feedback routes → Recommendation Service
# ---------------------------------------------------------------------------

@gateway_bp.route("/feedback", methods=["GET", "POST", "OPTIONS"])
def feedback():
    return _proxy("DYNAMIC", f"{RECOMMENDATION_SERVICE_URL}/feedback")


@gateway_bp.route("/feedback/<feedback_id>/resolve", methods=["POST", "OPTIONS"])
def resolve_feedback(feedback_id):
    return _proxy("POST", f"{RECOMMENDATION_SERVICE_URL}/feedback/{feedback_id}/resolve")


# ---------------------------------------------------------------------------
# Itinerary routes → Itinerary Service
# ---------------------------------------------------------------------------

@gateway_bp.route("/itineraries", methods=["GET", "POST", "OPTIONS"])
def itineraries():
    return _proxy("DYNAMIC", f"{ITINERARY_SERVICE_URL}/itineraries")


@gateway_bp.route("/itineraries/<itinerary_id>", methods=["PUT", "DELETE", "OPTIONS"])
def itinerary_detail(itinerary_id):
    return _proxy("DYNAMIC", f"{ITINERARY_SERVICE_URL}/itineraries/{itinerary_id}")
