import sys
from pathlib import Path

_service_dir = str(Path(__file__).resolve().parents[1])
if _service_dir not in sys.path:
    sys.path.insert(0, _service_dir)

import pytest

from app import create_app


@pytest.fixture
def client(tmp_path):
    app = create_app({
        "TESTING": True,
        "SECRET_KEY": "test-secret",
        "SQLITE_DATABASE_PATH": str(tmp_path / "destinations.db"),
        "CHAT_MEDIA_DIR": str(tmp_path / "chat-media"),
        "COPY_SEED_DATABASE": False,
    })
    with app.test_client() as test_client:
        yield test_client


def test_destination_search_filters_and_limits_results(client, monkeypatch):
    destinations = [
        {"id": "1", "name": "National Museum", "description": "History", "area": "Centre"},
        {"id": "2", "name": "Art Museum", "description": "Modern art", "area": "Centre"},
        {"id": "3", "name": "Mefou Park", "description": "Wildlife", "area": "South"},
    ]
    monkeypatch.setattr("app.routes.get_all_destinations", lambda: destinations)

    response = client.get("/destinations?q=museum&limit=1")

    assert response.status_code == 200
    assert [item["id"] for item in response.get_json()] == ["1"]


@pytest.mark.parametrize("value", ["0", "-1", "many"])
def test_destination_search_rejects_invalid_limit(client, value):
    response = client.get(f"/destinations?limit={value}")

    assert response.status_code == 400
    assert response.get_json()["error"] == "limit must be a positive integer"