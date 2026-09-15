"""tests/test_user_service.py — pytest suite for the User Service."""
import sys
from pathlib import Path

# Ensure the service directory is on sys.path so "app" is importable.
_service_dir = str(Path(__file__).resolve().parents[1])
if _service_dir not in sys.path:
    sys.path.insert(0, _service_dir)

import json
import os
import pytest

from app import create_app
from app.models import init_db


@pytest.fixture
def client():
    """Create a Flask test client with an initialized database."""
    app = create_app()
    app.config["TESTING"] = True

    with app.app_context():
        init_db(app)

    with app.test_client() as client:
        yield client


# ---- Registration Tests ----

def test_register_success(client):
    response = client.post(
        "/register",
        json={
            "username": "alice",
            "email": "alice@example.com",
            "password": "password123",
            "preferences": ["beach", "food"],
        },
    )
    assert response.status_code == 201
    data = response.get_json()
    assert "registered successfully" in data["message"].lower()
    assert data["username"] == "alice"


def test_register_missing_fields(client):
    # Missing password
    response = client.post("/register", json={"username": "alice", "email": "alice@example.com"})
    assert response.status_code == 400
    assert "required" in response.get_json()["error"]

    # Missing username
    response = client.post("/register", json={"password": "password123", "email": "alice@example.com"})
    assert response.status_code == 400

    # Missing email
    response = client.post("/register", json={"username": "alice", "password": "password123"})
    assert response.status_code == 400


def test_register_duplicate_username(client):
    client.post(
        "/register",
        json={"username": "dupuser", "email": "dup1@example.com", "password": "password123"},
    )
    response = client.post(
        "/register",
        json={"username": "dupuser", "email": "dup2@example.com", "password": "newpassword"},
    )
    assert response.status_code == 409
    assert response.get_json()["error"] == "username already exists"


# ---- Login Tests ----

def test_login_success(client):
    reg_res = client.post(
        "/register",
        json={"username": "bob", "email": "bob@example.com", "password": "secretpassword"},
    )
    code = reg_res.get_json().get("verification_code", "")
    if code:
        client.post("/verify", json={"username": "bob", "code": code})

    response = client.post("/login", json={"username": "bob", "password": "secretpassword"})
    assert response.status_code == 200
    data = response.get_json()
    assert "token" in data


def test_login_failed_credentials(client):
    reg_res = client.post(
        "/register",
        json={"username": "charlie", "email": "charlie@example.com", "password": "secretpassword"},
    )
    code = reg_res.get_json().get("verification_code", "")
    if code:
        client.post("/verify", json={"username": "charlie", "code": code})

    # Wrong password
    response = client.post("/login", json={"username": "charlie", "password": "wrongpassword"})
    assert response.status_code == 401

    # Non-existent user
    response = client.post("/login", json={"username": "nobody", "password": "secretpassword"})
    assert response.status_code == 401


def test_login_missing_fields(client):
    response = client.post("/login", json={"username": "bob"})
    assert response.status_code == 400


# ---- Internal routes ----

def test_internal_get_preferences(client):
    reg_res = client.post(
        "/register",
        json={
            "username": "diana",
            "email": "diana@example.com",
            "password": "secretpassword",
            "preferences": ["food", "nature"],
        },
    )
    code = reg_res.get_json().get("verification_code", "")
    if code:
        client.post("/verify", json={"username": "diana", "code": code})

    login_res = client.post("/login", json={"username": "diana", "password": "secretpassword"})
    token = login_res.get_json()["token"]

    # We need the user ID - extract from token's sub claim
    import jwt
    secret = os.environ.get("SECRET_KEY", "globetrotter-secret-change-in-prod")
    payload = jwt.decode(token, secret, algorithms=["HS256"])
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


def _disable_test_schema_reset(app, monkeypatch):
    # Simulate normal startup rather than the test fixture's table reset.
    monkeypatch.setitem(app.config, "TESTING", False)
    for name in ("PYTEST_CURRENT_TEST", "TESTING", "USE_SQLITE"):
        monkeypatch.delenv(name, raising=False)


def test_startup_schema_initialization_preserves_existing_users(client, monkeypatch):
    from app.models import get_user_by_username

    response = client.post(
        "/register",
        json={
            "username": "persistent-user",
            "email": "persistent-user@example.com",
            "password": "password123",
        },
    )
    assert response.status_code == 201
    original = get_user_by_username("persistent-user")
    assert original is not None

    _disable_test_schema_reset(client.application, monkeypatch)

    with client.application.app_context():
        init_db(client.application)
        init_db(client.application)
        restored = get_user_by_username("persistent-user")

    assert restored is not None
    assert restored["id"] == original["id"]


def test_startup_migrates_legacy_columns_before_creating_indexes(client, monkeypatch):
    from app.models import get_connection, get_user_by_username, release_connection

    conn = get_connection(client.application)
    cur = conn.cursor()
    cur.execute("DROP TABLE favorites")
    cur.execute("DROP TABLE users")
    cur.execute("""
        CREATE TABLE users (
            id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            preferences TEXT DEFAULT '[]',
            created_at TEXT NOT NULL
        )
    """)
    cur.execute(
        "INSERT INTO users (id, username, password_hash, created_at) "
        "VALUES (%s, %s, %s, %s)",
        ("legacy-id", "legacy-user", "unused-test-hash", "2026-01-01T00:00:00+00:00"),
    )
    conn.commit()
    cur.close()
    release_connection(conn)

    _disable_test_schema_reset(client.application, monkeypatch)
    with client.application.app_context():
        init_db(client.application)
        init_db(client.application)
        restored = get_user_by_username("legacy-user")

    assert restored is not None
    assert restored["id"] == "legacy-id"
    assert restored["email"] == ""
    assert not restored["is_verified"]
    assert restored["auth_provider"] == "local"
    assert restored["verification_code"] == ""
    assert restored["reset_code"] == ""
    assert restored["reset_expires"] == ""
