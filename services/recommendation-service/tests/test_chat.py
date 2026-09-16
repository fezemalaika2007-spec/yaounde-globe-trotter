"""Isolated shared-chat API, ownership, media, and persistence regressions."""
import base64
import io
import sqlite3
import sys
from pathlib import Path

import jwt
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import create_app
from app.chat import MAX_MEDIA_BYTES

KEY = "isolated-chat-tests-not-a-production-secret"
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aK1sAAAAASUVORK5CYII="
)
MP4 = b"\x00\x00\x00\x18ftypisom\x00\x00\x00\x00isommp42"
WEBM = b"\x1a\x45\xdf\xa3\x87\x42\x82\x84webm"


def auth(username, expiration=4102444800, secret=KEY):
    token = jwt.encode({"sub": username, "exp": expiration}, secret, algorithm="HS256")
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def config(tmp_path):
    return {
        "TESTING": True,
        "SECRET_KEY": KEY,
        "SQLITE_DATABASE_PATH": str(tmp_path / "destinations.db"),
        "CHAT_MEDIA_DIR": str(tmp_path / "media"),
        "COPY_SEED_DATABASE": False,
    }


@pytest.fixture
def app(config):
    return create_app(config)


def send(client, sender, message="Hello", **extra):
    return client.post(
        "/chat/messages", json={"message": message, **extra}, headers=auth(sender)
    )


def upload(client, content=PNG, filename="photo.png", content_type="application/octet-stream"):
    return client.post(
        "/chat/uploads",
        data={"file": (io.BytesIO(content), filename, content_type)},
        headers=auth("alice"),
    )


def test_two_users_and_guest_read_the_same_text_emoji_and_stickers(app):
    alice, bob, guest = app.test_client(), app.test_client(), app.test_client()
    first = send(alice, "alice", "Hello \U0001f60a", username="bob")
    second = send(bob, "bob", "Hi Alice")
    sticker = send(alice, "alice", "", media_type="sticker", media_url="\U0001f1e8\U0001f1f2 Explorer")
    assert [first.status_code, second.status_code, sticker.status_code] == [201, 201, 201]
    assert first.json["user_id"] == first.json["username"] == "alice"
    expected_ids = [first.json["id"], second.json["id"], sticker.json["id"]]
    for client, headers in ((alice, auth("alice")), (bob, auth("bob")), (guest, {})):
        response = client.get("/chat/messages", headers=headers)
        assert response.status_code == 200
        assert [message["id"] for message in response.json] == expected_ids
        assert response.json[0]["message"] == "Hello \U0001f60a"
        assert response.json[-1]["media_type"] == "sticker"
        assert response.headers["Cache-Control"] == "no-store"


@pytest.mark.parametrize("headers", [{}, auth("alice", expiration=1), auth("alice", secret="wrong-key")])
@pytest.mark.parametrize("method,path", [
    ("POST", "/chat/messages"), ("PUT", "/chat/messages/missing"),
    ("DELETE", "/chat/messages/missing"), ("POST", "/chat/uploads"),
])
def test_writes_require_valid_authentication(app, headers, method, path):
    response = app.test_client().open(path, method=method, json={"message": "No"}, headers=headers)
    assert response.status_code == 401
    assert response.json["error"] == "authentication required"


def test_edit_delete_only_succeed_for_the_actual_sender(app):
    alice, bob = app.test_client(), app.test_client()
    message = send(alice, "alice").json
    url = "/chat/messages/" + message["id"]
    for method in ("PUT", "DELETE"):
        denied = bob.open(url, method=method, json={"username": "alice", "message": "Hijacked"}, headers=auth("bob"))
        assert denied.status_code == 403
    changed = alice.put(url, json={"message": "Updated"}, headers=auth("alice"))
    assert changed.status_code == 200
    assert bob.get("/chat/messages").json[0]["message"] == "Updated"
    assert bob.get("/chat/messages").json[0]["is_edited"] == 1
    assert alice.delete(url, headers=auth("alice")).status_code == 200
    assert bob.get("/chat/messages").json == []
    assert alice.delete(url, headers=auth("alice")).status_code == 404
    assert alice.put(url, json={"message": "Missing"}, headers=auth("alice")).status_code == 404


@pytest.mark.parametrize("content,filename,mime,kind", [
    (PNG, "photo.png", "image/png", "image"),
    (b"\xff\xd8\xff\xe0test", "photo.jpg", "image/jpeg", "image"),
    (b"GIF89a" + bytes(12), "photo.gif", "image/gif", "image"),
    (b"RIFF" + bytes(4) + b"WEBP", "photo.webp", "image/webp", "image"),
    (MP4, "clip.mp4", "video/mp4", "video"),
    (WEBM, "clip.webm", "video/webm", "video"),
])
def test_uploads_are_shared_urls_readable_by_other_users(app, content, filename, mime, kind):
    alice, bob = app.test_client(), app.test_client()
    uploaded = upload(alice, content, filename)
    assert uploaded.status_code == 201
    assert uploaded.json["media_type"] == kind
    response = send(alice, "alice", "", **uploaded.json)
    assert response.status_code == 201
    feed = bob.get("/chat/messages")
    assert feed.json[0]["media_url"].startswith("/chat/media/")
    assert len(feed.data) < 1500
    media = bob.get(feed.json[0]["media_url"])
    assert media.status_code == 200
    assert media.data == content
    assert media.mimetype == mime
    assert media.headers["X-Content-Type-Options"] == "nosniff"


def test_video_range_and_head_work_after_application_restart(app, config):
    client = app.test_client()
    uploaded = upload(client, MP4, "clip.mp4").json
    message = send(client, "alice", "Video", **uploaded).json
    restarted = create_app(config).test_client()
    assert restarted.get("/chat/messages").json[0]["id"] == message["id"]
    partial = restarted.get(uploaded["media_url"], headers={"Range": "bytes=2-8"})
    assert partial.status_code == 206
    assert partial.data == MP4[2:9]
    assert partial.headers["Content-Range"] == f"bytes 2-8/{len(MP4)}"
    assert partial.headers["Accept-Ranges"] == "bytes"
    head = restarted.head(uploaded["media_url"])
    assert head.status_code == 200
    assert head.data == b""
    assert int(head.headers["Content-Length"]) == len(MP4)
    assert restarted.get(uploaded["media_url"], headers={"Range": "bytes=999-"}).status_code == 416


def test_exact_twenty_megabyte_limit_and_oversized_transport(app):
    client = app.test_client()
    content = PNG + bytes(MAX_MEDIA_BYTES - len(PNG))
    assert upload(client, content).status_code == 201
    oversized = upload(client, content + b"x")
    assert oversized.status_code == 413
    assert "20 MB" in oversized.json["error"]
    transport = client.post(
        "/chat/uploads", data=b"x",
        environ_overrides={"CONTENT_LENGTH": str(25 * 1024 * 1024 + 1)},
        content_type="multipart/form-data; boundary=test", headers=auth("alice"),
    )
    assert transport.status_code == 413
    assert transport.is_json


@pytest.mark.parametrize("content,claimed,status", [
    (b"", "image/png", 400),
    (b"<svg><script/></svg>", "image/png", 415),
    (PNG, "video/mp4", 415),
    (MP4.replace(b"isom", b"qt  ", 1), "video/mp4", 415),
])
def test_empty_unsupported_and_mislabelled_uploads_are_rejected(app, content, claimed, status):
    assert upload(app.test_client(), content, content_type=claimed).status_code == status


def test_upload_ownership_and_unshared_paths_are_rejected(app):
    client = app.test_client()
    uploaded = upload(client).json
    assert send(client, "bob", "", **uploaded).status_code == 403
    assert send(client, "alice", "", media_type="video", media_url=uploaded["media_url"]).status_code == 400
    for url in ("blob:device-local", "file:///private.png", "data:image/png;base64,AA==", "https://other.test/a.png"):
        response = send(client, "alice", "", media_type="image", media_url=url)
        assert response.status_code == 400
    assert client.get("/chat/media/private.db").status_code == 404
    assert client.get("/chat/media/" + "0" * 32 + ".png").status_code == 404


def test_reply_metadata_comes_from_the_shared_message(app):
    client = app.test_client()
    original = send(client, "bob", "Original").json
    reply = send(
        client, "alice", "Reply", reply_to_id=original["id"],
        reply_to_username="spoofed", reply_to_message="invented",
    )
    assert reply.status_code == 201
    assert reply.json["reply_to_username"] == "bob"
    assert reply.json["reply_to_message"] == "Original"
    assert send(client, "alice", "Reply", reply_to_id="missing").status_code == 400


@pytest.mark.parametrize("payload", [[], {}, {"message": 12}, {"message": "ok", "media_url": []}])
def test_invalid_messages_return_json_errors(app, payload):
    response = app.test_client().post("/chat/messages", json=payload, headers=auth("alice"))
    assert response.status_code == 400
    assert response.is_json


@pytest.mark.parametrize("limit", ["-1", "0", "invalid"])
def test_invalid_feed_limits(app, limit):
    assert app.test_client().get("/chat/messages?limit=" + limit).status_code == 400


def test_older_pages_survive_reopening_with_identical_timestamps(app, config):
    timestamp = "2026-09-01T12:00:00Z"
    with sqlite3.connect(config["SQLITE_DATABASE_PATH"]) as connection:
        connection.executemany(
            "INSERT INTO chat_messages (id, user_id, username, message, created_at) "
            "VALUES (?, 'alice', 'alice', ?, ?)",
            [(f"message-{i:03}", f"Saved conversation {i}", timestamp) for i in range(205)],
        )
    client = create_app(config).test_client()
    latest = client.get("/chat/messages").json
    assert len(latest) == 100
    assert latest[0]["id"] == "message-105"
    cursor = latest[0]
    # A deleted boundary message must not make its older history unreachable.
    assert client.delete("/chat/messages/" + cursor["id"], headers=auth("alice")).status_code == 200
    assert send(client, "bob", "A new message while scrolling").status_code == 201
    middle = client.get("/chat/messages", query_string={
        "before_created_at": cursor["created_at"], "before_id": cursor["id"],
    }).json
    assert [message["id"] for message in middle] == [f"message-{i:03}" for i in range(5, 105)]
    oldest = client.get("/chat/messages", query_string={
        "before_created_at": middle[0]["created_at"], "before_id": middle[0]["id"],
    }).json
    assert [message["id"] for message in oldest] == [f"message-{i:03}" for i in range(5)]
    exhausted = client.get("/chat/messages", query_string={
        "before_created_at": oldest[0]["created_at"], "before_id": oldest[0]["id"],
    }).json
    assert exhausted == []
    again = create_app(config).test_client().get("/chat/messages", query_string={
        "before_created_at": middle[0]["created_at"], "before_id": middle[0]["id"],
    }).json
    assert again == oldest


@pytest.mark.parametrize("cursor", [
    {"before_created_at": "2026-09-01T12:00:00Z"},
    {"before_id": "message-100"},
    {"before_created_at": "", "before_id": "message-100"},
    {"before_created_at": "not-a-date", "before_id": "message-100"},
    {"before_created_at": "2026-09-01T12:00:00Z", "before_id": ""},
])
def test_invalid_history_cursor_returns_json_error(app, cursor):
    response = app.test_client().get("/chat/messages", query_string=cursor)
    assert response.status_code == 400
    assert response.is_json


def test_existing_persistent_history_is_never_reseeded(config, tmp_path, monkeypatch):
    from app import models

    seed_root = tmp_path / "seed-service"
    seed_root.mkdir()
    monkeypatch.setattr(models, "__file__", str(seed_root / "app" / "models.py"))
    with sqlite3.connect(seed_root / "destinations.db") as connection:
        connection.execute(
            "CREATE TABLE chat_messages (id TEXT PRIMARY KEY, user_id TEXT, "
            "username TEXT, message TEXT, created_at TEXT)"
        )
        connection.execute(
            "INSERT INTO chat_messages VALUES "
            "('seed', 'alice', 'alice', 'Original history', '2026-09-01T00:00:00Z')"
        )
    config["COPY_SEED_DATABASE"] = True
    client = create_app(config).test_client()
    assert client.get("/chat/messages").json[0]["id"] == "seed"
    assert send(client, "bob", "Added after deployment").status_code == 201
    with sqlite3.connect(seed_root / "destinations.db") as connection:
        connection.execute("DELETE FROM chat_messages")
    restarted = create_app(config).test_client()
    assert [message["message"] for message in restarted.get("/chat/messages").json] == [
        "Original history", "Added after deployment",
    ]


def test_old_schema_is_upgraded_without_losing_history(config):
    with sqlite3.connect(config["SQLITE_DATABASE_PATH"]) as connection:
        connection.execute(
            "CREATE TABLE chat_messages (id TEXT PRIMARY KEY, user_id TEXT, username TEXT, message TEXT, created_at TEXT)"
        )
        connection.execute(
            "INSERT INTO chat_messages VALUES ('old', 'bob', 'bob', 'Keep me', '2026-09-01T00:00:00Z')"
        )
    client = create_app(config).test_client()
    assert client.get("/chat/messages").json[0]["message"] == "Keep me"
    assert send(client, "alice", "New").status_code == 201
    restarted = create_app(config).test_client()
    assert len(restarted.get("/chat/messages").json) == 2


def test_database_failure_is_not_reported_as_an_empty_feed(app, config):
    with sqlite3.connect(config["SQLITE_DATABASE_PATH"]) as connection:
        connection.execute("DROP TABLE chat_messages")
    response = app.test_client().get("/chat/messages")
    assert response.status_code == 503
    assert "storage" in response.json["error"]


def test_failed_upload_does_not_leave_an_orphaned_media_file(app, config):
    with sqlite3.connect(config["SQLITE_DATABASE_PATH"]) as connection:
        connection.execute("DROP TABLE chat_uploads")
    response = upload(app.test_client())
    assert response.status_code == 503
    assert response.is_json
    assert list(Path(config["CHAT_MEDIA_DIR"]).iterdir()) == []


def test_legacy_inline_photo_is_preserved_for_other_readers(app, config):
    legacy_url = "data:image/png;base64," + base64.b64encode(PNG).decode()
    with sqlite3.connect(config["SQLITE_DATABASE_PATH"]) as connection:
        connection.execute(
            "INSERT INTO chat_messages "
            "(id, user_id, username, message, media_url, media_type, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            ("legacy", "alice", "alice", "Existing photo", legacy_url, "image", "2026-09-01T00:00:00Z"),
        )
    restarted = create_app(config).test_client()
    response = restarted.get("/chat/messages", headers=auth("bob"))
    assert response.status_code == 200
    assert response.json[0]["media_url"] == legacy_url
