"""tests/test_api_gateway.py — pytest suite for the API Gateway.

The gateway contains no business logic; it proxies requests to the backend
microservices. These tests verify the proxy routing, health check, and that
requests are forwarded to the correct service URL with the correct method,
headers, query params, and JSON body.

Run from services/api-gateway:
    python -m pytest tests/ -q
"""
import sys
import json
from pathlib import Path
from unittest import mock

# Ensure the service dir is importable.
_service_dir = str(Path(__file__).resolve().parents[1])
if _service_dir not in sys.path:
    sys.path.insert(0, _service_dir)

import pytest

from app import create_app


@pytest.fixture
def app():
    """Create a test app."""
    application = create_app()
    application.config["TESTING"] = True
    return application


@pytest.fixture
def mock_routes_urls():
    """Point the gateway's module-level backend URLs at fake hosts."""
    with mock.patch("app.routes.USER_SERVICE_URL", "http://user.test:5001"), \
         mock.patch("app.routes.ITINERARY_SERVICE_URL", "http://itinerary.test:5002"), \
         mock.patch("app.routes.RECOMMENDATION_SERVICE_URL", "http://rec.test:5003"):
        yield


@pytest.fixture
def client(app):
    with app.test_client() as c:
        yield c


def _mock_response(status_code=200, payload=None):
    """Build a fake requests.Response."""
    resp = mock.Mock()
    resp.status_code = status_code
    resp.content = json.dumps(payload or {}).encode()
    resp.headers = {"Content-Type": "application/json"}
    resp.ok = status_code < 400
    return resp


# ---- Health check ----

def test_health_all_ok(client, app):
    def fake_get(url, timeout=None):
        return _mock_response(200, {"status": "ok"})

    with mock.patch("app.routes.requests.get", side_effect=fake_get):
        resp = client.get("/health")
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["status"] == "ok"
        assert data["services"]["user-service"] == "ok"


# ---- Proxy routing ----

def test_register_proxies_to_user_service(client, app, mock_routes_urls):
    with mock.patch("app.routes.requests.request") as mock_request:
        mock_request.return_value = _mock_response(
            201, {"message": "user registered successfully"}
        )
        resp = client.post(
            "/register",
            json={"username": "alice", "password": "secret", "preferences": ["food"]},
        )
        assert resp.status_code == 201
        call = mock_request.call_args
        kwargs = call.kwargs
        assert kwargs["url"].startswith("http://user.test:5001/register")
        assert kwargs["method"].lower() == "post"
        assert kwargs["json"]["username"] == "alice"


def test_login_proxies_to_user_service(client, app, mock_routes_urls):
    with mock.patch("app.routes.requests.request") as mock_request:
        mock_request.return_value = _mock_response(200, {"token": "fake-jwt-token"})
        resp = client.post("/login", json={"username": "alice", "password": "secret"})
        assert resp.status_code == 200
        assert resp.get_json()["token"] == "fake-jwt-token"
        call = mock_request.call_args
        assert call.kwargs["url"].startswith("http://user.test:5001/login")


def test_get_destinations_proxies_to_recommendation(client, app, mock_routes_urls):
    with mock.patch("app.routes.requests.request") as mock_request:
        mock_request.return_value = _mock_response(
            200, [{"name": "Mefou Park", "id": "1"}]
        )
        resp = client.get("/destinations?tag=food&max_cost=10000")
        assert resp.status_code == 200
        call = mock_request.call_args
        assert call.kwargs["url"].startswith("http://rec.test:5003/destinations")
        assert call.kwargs["params"] == {"tag": "food", "max_cost": "10000"}


def test_rating_proxies_with_auth_header(client, app, mock_routes_urls):
    with mock.patch("app.routes.requests.request") as mock_request:
        mock_request.return_value = _mock_response(
            200, {"message": "rating submitted successfully", "average_rating": 4.5}
        )
        resp = client.post(
            "/destinations/abc123/rating",
            json={"rating": 5},
            headers={"Authorization": "Bearer test-token"},
        )
        assert resp.status_code == 200
        call = mock_request.call_args
        assert call.kwargs["url"].endswith("/destinations/abc123/rating")
        assert call.kwargs["headers"]["Authorization"] == "Bearer test-token"


def test_recommendations_proxies_with_auth(client, app, mock_routes_urls):
    with mock.patch("app.routes.requests.request") as mock_request:
        mock_request.return_value = _mock_response(
            200,
            {
                "sections": [
                    {"title": "Top Rated", "type": "top_rated", "items": []}
                ],
                "recommendations": [],
            },
        )
        resp = client.get(
            "/recommendations", headers={"Authorization": "Bearer test-token"}
        )
        assert resp.status_code == 200
        call = mock_request.call_args
        assert call.kwargs["url"].startswith("http://rec.test:5003/recommendations")
        assert call.kwargs["headers"]["Authorization"] == "Bearer test-token"


def test_itineraries_proxies_to_itinerary(client, app, mock_routes_urls):
    with mock.patch("app.routes.requests.request") as mock_request:
        mock_request.return_value = _mock_response(201, {"id": "itin-1"})
        resp = client.post(
            "/itineraries",
            json={
                "title": "Trip",
                "destinations": ["Museum"],
                "start_date": "2025-06-01",
                "end_date": "2025-06-05",
            },
            headers={"Authorization": "Bearer test-token"},
        )
        assert resp.status_code == 201
        call = mock_request.call_args
        assert call.kwargs["url"].startswith("http://itinerary.test:5002/itineraries")
        assert call.kwargs["headers"]["Authorization"] == "Bearer test-token"


def test_favorites_proxies_to_user(client, app, mock_routes_urls):
    with mock.patch("app.routes.requests.request") as mock_request:
        mock_request.return_value = _mock_response(200, ["Mefou Park"])
        resp = client.get("/favorites", headers={"Authorization": "Bearer t"})
        assert resp.status_code == 200
        call = mock_request.call_args
        assert call.kwargs["url"].startswith("http://user.test:5001/favorites")


def test_service_unavailable(client, app, mock_routes_urls):
    from requests.exceptions import ConnectionError
    with mock.patch("app.routes.requests.request", side_effect=ConnectionError()):
        resp = client.get("/destinations")
        assert resp.status_code == 503
        assert resp.get_json()["error"] == "service unavailable"


def test_comments_proxy_get_and_post(client, app, mock_routes_urls):
    with mock.patch("app.routes.requests.request") as mock_request:
        mock_request.return_value = _mock_response(200, [{"id": "c1", "text": "Nice place"}])
        resp = client.get("/destinations/dest-1/comments")
        assert resp.status_code == 200
        call = mock_request.call_args
        assert call.kwargs["url"].startswith("http://rec.test:5003/destinations/dest-1/comments")


def test_comment_edit_put_and_delete(client, app, mock_routes_urls):
    with mock.patch("app.routes.requests.request") as mock_request:
        # Test PUT (edit comment)
        mock_request.return_value = _mock_response(200, {"id": "c1", "text": "Updated text"})
        resp_put = client.put(
            "/destinations/dest-1/comments/c1",
            json={"text": "Updated text"},
            headers={"Authorization": "Bearer token123"},
        )
        assert resp_put.status_code == 200
        assert mock_request.call_args.kwargs["url"].endswith("/destinations/dest-1/comments/c1")
        assert mock_request.call_args.kwargs["method"].lower() == "put"

        # Test DELETE (delete comment)
        mock_request.return_value = _mock_response(200, {"message": "comment deleted"})
        resp_del = client.delete(
            "/destinations/dest-1/comments/c1",
            headers={"Authorization": "Bearer token123"},
        )
        assert resp_del.status_code == 200
        assert mock_request.call_args.kwargs["url"].endswith("/destinations/dest-1/comments/c1")
        assert mock_request.call_args.kwargs["method"].lower() == "delete"


def test_notifications_routes(client, app, mock_routes_urls):
    with mock.patch("app.routes.requests.request") as mock_request:
        mock_request.return_value = _mock_response(200, [{"id": "n1", "title": "Reply"}])
        resp = client.get("/notifications", headers={"Authorization": "Bearer token123"})
        assert resp.status_code == 200
        assert mock_request.call_args.kwargs["url"].startswith("http://rec.test:5003/notifications")

