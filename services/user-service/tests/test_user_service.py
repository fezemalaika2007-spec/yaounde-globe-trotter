"""tests/test_user_service.py — pytest suite for the User Service."""
import json
import os
import pytest
import tempfile

from app import create_app
from app.models import init_db, get_db_path


@pytest.fixture
def client():
    """Create a Flask test client with a temporary database."""
    app = create_app()
    app.config["TESTING"] = True
    # Use temp dir for database
    tmp_dir = tempfile.mkdtemp()
    db_path = os.path.join(tmp_dir, "test_users.db")
    app.config["DATABASE"] = db_path

    with app.app_context():
        init_db(app)

    with app.test_client() as client:
        yield client

    # Cleanup
    if os.path.exists(db_path):
        os.remove(db_path)


# ---- Registration Tests ----

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


# ---- Login Tests ----

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


# ---- Internal routes ----

def test_internal_get_preferences(client):
    client.post("/register", json={"username": "diana", "password": "pass", "preferences": ["food", "nature"]})
    login_res = client.post("/login", json={"username": "diana", "password": "pass"})
    token = login_res.get_json()["token"]

    # We need the user ID - extract from token's sub claim
    import jwt
    payload = jwt.decode(token, "globetrotter-secret-change-in-prod", algorithms=["HS256"])
    username = payload["sub"]

    # Get user from the model to find their ID
    from app.models import get_user_by_username
    user = get_user_by_username(username)
    assert user is not None

    response = client.get(f"/internal/users/{user['id']}/preferences")
    assert response.status_code == 200
    data = response.get_json()
    assert data["username"] == "diana"
    assert "food" in data["preferences"]


def test_cors_headers(client):
    response = client.get("/login")
    # Login is POST, but CORS headers should still be present
    assert "Access-Control-Allow-Origin" in response.headers

