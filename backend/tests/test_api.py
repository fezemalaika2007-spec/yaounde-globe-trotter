"""
tests/test_api.py

Comprehensive test suite covering authentication, destinations catalog search,
recommendations engine, itinerary creation/listing, user scoping, and error handling.
"""
import json
import pytest
from app import create_app
import app.models as models


@pytest.fixture
def client(tmp_path, monkeypatch):
    """Create a Flask test client with temporary data directory."""
    test_users_file = str(tmp_path / "users.json")
    test_itineraries_file = str(tmp_path / "itineraries.json")

    monkeypatch.setattr(models, "USERS_FILE", test_users_file)
    monkeypatch.setattr(models, "ITINERARIES_FILE", test_itineraries_file)

    app = create_app()
    app.config["TESTING"] = True

    with app.test_client() as client:
        yield client


# ---------------------------------------------------------------------------
# Registration Tests
# ---------------------------------------------------------------------------

def test_register_success(client):
    response = client.post(
        "/register",
        json={"username": "alice", "password": "password123", "preferences": ["beach", "food"]},
    )
    assert response.status_code == 201
    data = response.get_json()
    assert data["message"] == "user registered successfully"
    assert data["username"] == "alice"


def test_register_missing_fields(client):
    # Missing password
    response = client.post("/register", json={"username": "alice"})
    assert response.status_code == 400
    assert "required" in response.get_json()["error"]

    # Missing username
    response = client.post("/register", json={"password": "password123"})
    assert response.status_code == 400


def test_register_duplicate_username(client):
    client.post("/register", json={"username": "alice", "password": "password123"})
    response = client.post("/register", json={"username": "alice", "password": "newpassword"})
    assert response.status_code == 409
    assert response.get_json()["error"] == "username already exists"


# ---------------------------------------------------------------------------
# Login Tests
# ---------------------------------------------------------------------------

def test_login_success(client):
    client.post("/register", json={"username": "bob", "password": "secretpassword"})
    response = client.post("/login", json={"username": "bob", "password": "secretpassword"})
    assert response.status_code == 200
    data = response.get_json()
    assert "token" in data


def test_login_failed_credentials(client):
    client.post("/register", json={"username": "bob", "password": "secretpassword"})

    # Wrong password
    response = client.post("/login", json={"username": "bob", "password": "wrongpassword"})
    assert response.status_code == 401

    # Non-existent user
    response = client.post("/login", json={"username": "charlie", "password": "secretpassword"})
    assert response.status_code == 401


def test_login_missing_fields(client):
    response = client.post("/login", json={"username": "bob"})
    assert response.status_code == 400


# ---------------------------------------------------------------------------
# Destinations Endpoint Tests
# ---------------------------------------------------------------------------

def test_get_destinations_all(client):
    response = client.get("/destinations")
    assert response.status_code == 200
    data = response.get_json()
    assert isinstance(data, list)
    assert len(data) == 12


def test_get_destinations_filter_tag(client):
    response = client.get("/destinations?tag=nature")
    assert response.status_code == 200
    data = response.get_json()
    assert all("nature" in dest["tags"] for dest in data)


def test_get_destinations_filter_continent(client):
    response = client.get("/destinations?continent=Africa")
    assert response.status_code == 200
    data = response.get_json()
    assert all(dest["continent"].lower() == "africa" for dest in data)


def test_get_destinations_filter_search(client):
    response = client.get("/destinations?q=Mont")
    assert response.status_code == 200
    data = response.get_json()
    assert len(data) >= 2
    names = [d["name"] for d in data]
    assert "Mont Fébé" in names


def test_get_destinations_filter_max_cost(client):
    response = client.get("/destinations?max_cost=150")
    assert response.status_code == 200
    data = response.get_json()
    assert all(dest["avg_cost_per_day"] <= 150 for dest in data)


def test_get_destinations_invalid_max_cost(client):
    response = client.get("/destinations?max_cost=notanumber")
    assert response.status_code == 400
    assert "must be an integer" in response.get_json()["error"]


# ---------------------------------------------------------------------------
# Recommendations Tests
# ---------------------------------------------------------------------------

def test_recommendations_without_auth(client):
    response = client.get("/recommendations")
    assert response.status_code == 401


def test_recommendations_with_auth(client):
    client.post("/register", json={"username": "diana", "password": "pass", "preferences": ["beach", "food"]})
    login_res = client.post("/login", json={"username": "diana", "password": "pass"})
    token = login_res.get_json()["token"]

    response = client.get(
        "/recommendations?limit=3",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.get_json()
    assert len(data) <= 3
    # Check that highest match score comes first
    scores = [item["match_score"] for item in data]
    assert scores == sorted(scores, reverse=True)


# ---------------------------------------------------------------------------
# Itineraries Tests & User Scoping
# ---------------------------------------------------------------------------

def test_itinerary_creation_without_auth(client):
    response = client.post(
        "/itineraries",
        json={"title": "Trip", "destinations": ["Paris"], "start_date": "2025-06-01", "end_date": "2025-06-10"},
    )
    assert response.status_code == 401


def test_itinerary_creation_missing_fields(client):
    client.post("/register", json={"username": "eve", "password": "pass"})
    token = client.post("/login", json={"username": "eve", "password": "pass"}).get_json()["token"]
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

    # Missing end_date
    res = client.post("/itineraries", json={"title": "Trip", "destinations": ["Paris"], "start_date": "2025-06-01"}, headers=headers)
    assert res.status_code == 400


def test_itinerary_user_scoping(client):
    # Register User A and User B
    client.post("/register", json={"username": "userA", "password": "passA"})
    client.post("/register", json={"username": "userB", "password": "passB"})

    tokenA = client.post("/login", json={"username": "userA", "password": "passA"}).get_json()["token"]
    tokenB = client.post("/login", json={"username": "userB", "password": "passB"}).get_json()["token"]

    headersA = {"Authorization": f"Bearer {tokenA}"}
    headersB = {"Authorization": f"Bearer {tokenB}"}

    # User A creates an itinerary
    res_create = client.post(
        "/itineraries",
        json={"title": "User A's Escape", "destinations": ["Santorini"], "start_date": "2025-07-01", "end_date": "2025-07-10"},
        headers=headersA,
    )
    assert res_create.status_code == 201

    # User A lists itineraries -> should see 1
    resA = client.get("/itineraries", headers=headersA)
    assert resA.status_code == 200
    itinsA = resA.get_json()
    assert len(itinsA) == 1
    assert itinsA[0]["title"] == "User A's Escape"

    # User B lists itineraries -> should see 0 (user scoping enforced)
    resB = client.get("/itineraries", headers=headersB)
    assert resB.status_code == 200
    itinsB = resB.get_json()
    assert len(itinsB) == 0


def test_cors_headers(client):
    response = client.get("/destinations")
    assert response.status_code == 200
    assert "Access-Control-Allow-Origin" in response.headers
