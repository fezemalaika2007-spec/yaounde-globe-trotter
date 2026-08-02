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
    headers = {
        "Content-Type": "application/json",
    }
    # Pass through Authorization header
    auth = request.headers.get("Authorization")
    if auth:
        headers["Authorization"] = auth

    # Forward query parameters
    params = dict(request.args)

    try:
        resp = requests.request(
            method=method,
            url=target_url,
            headers=headers,
            params=params if params else None,
            json=request.get_json(silent=True) or None,
            timeout=30,
        )
        # Return the backend service's response as-is
        return Response(
            response=resp.content,
            status=resp.status_code,
            content_type=resp.headers.get("Content-Type", "application/json"),
        )
    except requests.exceptions.ConnectionError:
        return jsonify({"error": "service unavailable"}), 503
    except requests.exceptions.Timeout:
        return jsonify({"error": "service timeout"}), 504


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

@gateway_bp.route("/health", methods=["GET"])
def health():
    """Check all backend services are reachable."""
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

@gateway_bp.route("/register", methods=["POST"])
def register():
    return _proxy("POST", f"{USER_SERVICE_URL}/register")


@gateway_bp.route("/login", methods=["POST"])
def login():
    return _proxy("POST", f"{USER_SERVICE_URL}/login")


# ---------------------------------------------------------------------------
# Destination & Recommendation routes → Recommendation Service
# ---------------------------------------------------------------------------

@gateway_bp.route("/destinations", methods=["GET"])
def get_destinations():
    return _proxy("GET", f"{RECOMMENDATION_SERVICE_URL}/destinations")


@gateway_bp.route("/destinations/<dest_id>/rating", methods=["POST"])
def submit_rating(dest_id):
    return _proxy("POST", f"{RECOMMENDATION_SERVICE_URL}/destinations/{dest_id}/rating")


@gateway_bp.route("/recommendations", methods=["GET"])
def get_recommendations():
    return _proxy("GET", f"{RECOMMENDATION_SERVICE_URL}/recommendations")


@gateway_bp.route("/favorites", methods=["GET", "POST"])
def favorites():
    method = request.method
    return _proxy(method, f"{USER_SERVICE_URL}/favorites")


@gateway_bp.route("/search", methods=["GET"])
def search_destinations():
    """Live internet search for destinations in Yaoundé (Overpass)."""
    return _proxy("GET", f"{RECOMMENDATION_SERVICE_URL}/search")


@gateway_bp.route("/sync-destinations", methods=["POST"])
def sync_destinations():
    return _proxy("POST", f"{RECOMMENDATION_SERVICE_URL}/sync-destinations")


# ---------------------------------------------------------------------------
# Itinerary routes → Itinerary Service
# ---------------------------------------------------------------------------

@gateway_bp.route("/itineraries", methods=["GET", "POST"])
def itineraries():
    method = request.method
    return _proxy(method, f"{ITINERARY_SERVICE_URL}/itineraries")
