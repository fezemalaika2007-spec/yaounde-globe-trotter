"""tests/test_itinerary_service.py — pytest suite for the Itinerary Service."""
import json
import os
import pytest
import tempfile

from app import create_app
from app.models import init_db


@pytest.fixture
def client():
    """Create a Flask test client against the configured online PostgreSQL DB.

    The Itinerary Service now uses an online PostgreSQL database configured
    via the DATABASE_URL environment variable (never hardcoded). If
    DATABASE_URL is not set, the tests skip gracefully so the suite stays
    runnable without cloud credentials.
    """
    if not os.environ.get("DATABASE_URL"):
        pytest.skip("DATABASE_URL not set; skipping PostgreSQL-backed tests")

    app = create_app()
    app.config["TESTING"] = True
    app.config["SECRET_KEY"] = "test-secret"

    with app.app_context():
        init_db(app)

    with app.test_client() as client:
        yield client


def _get_token(client, username="testuser"):
    """Helper: create a valid JWT for testing."""
    import jwt
    import datetime
    now = datetime.datetime.now(datetime.timezone.utc)
    payload = {
        "sub": username,
        "iat": now,
        "exp": now + datetime.timedelta(hours=24),
    }
    return jwt.encode(payload, "test-secret", algorithm="HS256")


# ---- Auth tests ----

def test_itinerary_creation_without_auth(client):
    response = client.post(
        "/itineraries",
        json={"title": "Trip", "destinations": ["Paris"], "start_date": "2025-06-01", "end_date": "2025-06-10"},
    )
    assert response.status_code == 401


def test_itinerary_list_without_auth(client):
    response = client.get("/itineraries")
    assert response.status_code == 401


# ---- Creation tests ----

def test_itinerary_creation_success(client):
    token = _get_token(client)
    headers = {"Authorization": f"Bearer {token}"}
    response = client.post(
        "/itineraries",
        json={
            "title": "Summer in Yaoundé",
            "destinations": ["Mont Fébé", "Mefou National Park"],
            "start_date": "2025-06-01",
            "end_date": "2025-06-15",
        },
        headers=headers,
    )
    assert response.status_code == 201
    data = response.get_json()
    assert data["title"] == "Summer in Yaoundé"
    assert data["username"] == "testuser"
    assert "id" in data


def test_itinerary_creation_missing_fields(client):
    token = _get_token(client)
    headers = {"Authorization": f"Bearer {token}"}

    # Missing title
    res = client.post("/itineraries", json={"destinations": ["Paris"], "start_date": "2025-06-01", "end_date": "2025-06-10"}, headers=headers)
    assert res.status_code == 400

    # Missing destinations
    res = client.post("/itineraries", json={"title": "Trip", "start_date": "2025-06-01", "end_date": "2025-06-10"}, headers=headers)
    assert res.status_code == 400

    # Missing start_date
    res = client.post("/itineraries", json={"title": "Trip", "destinations": ["Paris"], "end_date": "2025-06-10"}, headers=headers)
    assert res.status_code == 400


# ---- User scoping tests ----

def test_itinerary_user_scoping(client):
    token_a = _get_token(client, "userA")
    token_b = _get_token(client, "userB")
    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # User A creates an itinerary
    res_create = client.post(
        "/itineraries",
        json={"title": "User A's Escape", "destinations": ["Santorini"], "start_date": "2025-07-01", "end_date": "2025-07-10"},
        headers=headers_a,
    )
    assert res_create.status_code == 201

    # User A lists -> should see 1
    res_a = client.get("/itineraries", headers=headers_a)
    assert res_a.status_code == 200
    itins_a = res_a.get_json()
    assert len(itins_a) == 1
    assert itins_a[0]["title"] == "User A's Escape"

    # User B lists -> should see 0
    res_b = client.get("/itineraries", headers=headers_b)
    assert res_b.status_code == 200
    itins_b = res_b.get_json()
    assert len(itins_b) == 0


# ---- Internal routes ----

def test_internal_get_itineraries_by_user_id(client):
    token = _get_token(client, "internalUser")
    headers = {"Authorization": f"Bearer {token}"}
    client.post(
        "/itineraries",
        json={"title": "Internal Test", "destinations": ["Place A"], "start_date": "2025-08-01", "end_date": "2025-08-05"},
        headers=headers,
    )

    # We don't have the user_id, but we can test the route returns a list
    response = client.get("/internal/users/nonexistent/itineraries")
    assert response.status_code == 200
    data = response.get_json()
    assert isinstance(data, list)

