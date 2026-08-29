"""tests/test_preferences_endpoint.py — Tests for the new
/internal/users/preferences endpoint in the User Service."""
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


def _register_and_login(client, username="alice", password="mypassword"):
    """Helper: register + verify email + login, return the JWT token."""
    reg_res = client.post(
        "/register",
        json={
            "username": username,
            "email": f"{username}@example.com",
            "password": password,
            "preferences": ["food", "nature"],
        },
    )
    code = reg_res.get_json().get("verification_code", "")
    if code:
        client.post("/verify", json={"username": username, "code": code})

    resp = client.post("/login", json={"username": username, "password": password})
    return resp.get_json()["token"]


class TestInternalPreferencesEndpoint:
    def test_get_preferences_and_favorites(self, client):
        token = _register_and_login(client, "diana", "mypassword")
        headers = {"Authorization": f"Bearer {token}"}

        resp = client.get("/internal/users/preferences", headers=headers)
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["username"] == "diana"
        assert "food" in data["preferences"]
        assert "favorites" in data
        assert isinstance(data["favorites"], list)

    def test_add_favorite_then_preferences_include_it(self, client):
        token = _register_and_login(client, "bob", "mypassword")
        headers = {"Authorization": f"Bearer {token}"}

        # Add a favorite
        client.post(
            "/favorites",
            headers=headers,
            json={"destination": "Mefou National Park"},
        )

        # Check preferences includes it
        resp = client.get("/internal/users/preferences", headers=headers)
        assert resp.status_code == 200
        data = resp.get_json()
        assert "Mefou National Park" in data["favorites"]

    def test_no_auth_returns_401(self, client):
        resp = client.get("/internal/users/preferences")
        assert resp.status_code == 401

    def test_invalid_token_returns_401(self, client):
        headers = {"Authorization": "Bearer invalidtoken"}
        resp = client.get("/internal/users/preferences", headers=headers)
        assert resp.status_code == 401
