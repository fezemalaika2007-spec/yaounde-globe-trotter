"""tests/test_integration_journey.py — Consolidated full-journey integration test.

This suite runs the complete user journey through the API Gateway, with the
backend microservices mocked to respond as real services would. It verifies
that the gateway correctly orchestrates:

    register -> login -> search/filter destinations -> view a destination
    detail -> submit a rating -> view recommendations -> create an itinerary
    -> list itineraries -> logout

Because the gateway is a pure proxy (no business logic), this test mocks the
`requests.request` calls the proxy makes to the backend and asserts the
responses flow back to the client correctly at each step.

Run from services/api-gateway:
    python -m pytest tests/test_integration_journey.py -q
"""
import sys
import json
from pathlib import Path
from unittest import mock

_service_dir = str(Path(__file__).resolve().parents[1])
if _service_dir not in sys.path:
    sys.path.insert(0, _service_dir)

import pytest

from app import create_app


@pytest.fixture
def app():
    application = create_app()
    application.config["TESTING"] = True
    return application


@pytest.fixture
def mock_routes_urls():
    with mock.patch("app.routes.USER_SERVICE_URL", "http://user.test:5001"), \
         mock.patch("app.routes.ITINERARY_SERVICE_URL", "http://itinerary.test:5002"), \
         mock.patch("app.routes.RECOMMENDATION_SERVICE_URL", "http://rec.test:5003"):
        yield


@pytest.fixture
def client(app):
    with app.test_client() as c:
        yield c


def _mock_response(status_code=200, payload=None):
    resp = mock.Mock()
    resp.status_code = status_code
    resp.content = json.dumps(payload or {}).encode()
    resp.headers = {"Content-Type": "application/json"}
    resp.ok = status_code < 400
    return resp


def _mock_backend(mock_request, responses):
    """Configure mock_request to return responses based on URL + method.

    responses is a list of (method, url_keyword, status, payload) tuples,
    checked in order. The most specific keyword should come first.
    """
    def side_effect(method, url, headers=None, params=None, json=None, timeout=None):
        url_lower = url.lower()
        method_lower = (method or "").lower()
        for kw_method, keyword, status, payload in responses:
            if keyword in url_lower and (kw_method is None or kw_method == method_lower):
                return _mock_response(status, payload)
        return _mock_response(404, {"error": "not found"})

    mock_request.side_effect = side_effect


def test_full_user_journey_through_gateway(client, app, mock_routes_urls):
    """The complete app journey, flowing through the API Gateway."""
    token = "jwt-token-abc123"

# The backend microservices' expected responses at each step.
    # Format: (method_or_None, url_keyword, status, payload)
    backend_responses = [
        # 1. register
        ("post", "user.test:5001/register", 201, {"message": "user registered successfully"}),
        # 2. login
        ("post", "user.test:5001/login", 200, {"token": token}),
        # 3. search/filter destinations
        ("get", "rec.test:5003/destinations", 200, [
            {
                "id": "dest-1",
                "name": "Mefou National Park",
                "category": "nature",
                "average_rating": 4.6,
                "rating_count": 10,
                "cost": 5000,
                "long_description": "A long description of Mefou National Park.",
            }
        ]),
        # 4. submit a rating
        ("post", "rec.test:5003/destinations/dest-1/rating", 200,
         {"message": "rating submitted successfully", "average_rating": 4.6, "rating_count": 11}),
        # 5. view recommendations
        ("get", "rec.test:5003/recommendations", 200, {
            "sections": [
                {"title": "Top Rated", "type": "top_rated", "items": []},
            ],
            "recommendations": [],
        }),
        # 6. create itinerary (POST)
        ("post", "itinerary.test:5002/itineraries", 201,
         {"id": "itin-1", "title": "Weekend in Yaoundé", "username": "alice"}),
        # 7. list itineraries (GET)
        ("get", "itinerary.test:5002/itineraries", 200,
         [{"id": "itin-1", "title": "Weekend in Yaoundé", "username": "alice"}]),
    ]

    with mock.patch("app.routes.requests.request") as mock_request:
        _mock_backend(mock_request, backend_responses)

        # 1. Register
        r = client.post("/register", json={"username": "alice", "password": "secret"})
        assert r.status_code == 201

        # 2. Login
        r = client.post("/login", json={"username": "alice", "password": "secret"})
        assert r.status_code == 200
        assert r.get_json()["token"] == token

        auth = {"Authorization": f"Bearer {token}"}

        # 3. Search / filter destinations
        r = client.get("/destinations?tag=nature")
        assert r.status_code == 200
        dests = r.get_json()
        assert len(dests) == 1
        assert dests[0]["name"] == "Mefou National Park"

        # 4. View a destination detail (via GET destinations then rating)
        dest_id = dests[0]["id"]
        r = client.post(f"/destinations/{dest_id}/rating", json={"rating": 5}, headers=auth)
        assert r.status_code == 200
        assert r.get_json()["rating_count"] == 11

        # 5. View recommendations
        r = client.get("/recommendations", headers=auth)
        assert r.status_code == 200
        data = r.get_json()
        assert "sections" in data

        # 6. Create itinerary
        r = client.post(
            "/itineraries",
            json={
                "title": "Weekend in Yaoundé",
                "destinations": ["Mefou National Park"],
                "start_date": "2025-06-01",
                "end_date": "2025-06-03",
            },
            headers=auth,
        )
        assert r.status_code == 201
        assert r.get_json()["title"] == "Weekend in Yaoundé"

        # 7. List itineraries
        r = client.get("/itineraries", headers=auth)
        assert r.status_code == 200
        itins = r.get_json()
        assert len(itins) == 1
        assert itins[0]["title"] == "Weekend in Yaoundé"


def test_unauthorized_during_journey_returns_401(client, app, mock_routes_urls):
    """If a protected backend call returns 401, the gateway propagates it."""
    with mock.patch("app.routes.requests.request") as mock_request:
        mock_request.return_value = _mock_response(401, {"error": "invalid token"})
        r = client.get("/recommendations", headers={"Authorization": "Bearer bad"})
        assert r.status_code == 401
        assert r.get_json()["error"] == "invalid token"


def test_journey_degrades_gracefully_when_service_down(client, app, mock_routes_urls):
    """If a backend service is unreachable, the gateway returns 503."""
    from requests.exceptions import ConnectionError

    def side_effect(method, url, headers=None, params=None, json=None, timeout=None):
        if "user.test" in url:
            raise ConnectionError()
        return _mock_response(200, [])

    with mock.patch("app.routes.requests.request", side_effect=side_effect):
        r = client.post("/login", json={"username": "alice", "password": "secret"})
        assert r.status_code == 503
        assert r.get_json()["error"] == "service unavailable"
