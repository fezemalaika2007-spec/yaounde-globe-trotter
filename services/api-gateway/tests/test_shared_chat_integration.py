"""Exercise the gateway against a real, isolated recommendation HTTP service.

Requires the dependencies of both services, but no Docker or production data.
"""
import base64
import hashlib
import hmac
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import create_app

KEY = "isolated-integration-chat-key"


def _auth(username):
    def encode(value):
        return base64.urlsafe_b64encode(value).rstrip(b"=")

    header = encode(b'{"alg":"HS256","typ":"JWT"}')
    claims = encode(json.dumps({"sub": username, "exp": 4102444800}).encode())
    signing_input = header + b"." + claims
    signature = encode(hmac.new(KEY.encode(), signing_input, hashlib.sha256).digest())
    return {"Authorization": "Bearer " + (signing_input + b"." + signature).decode()}


@pytest.fixture
def gateway(tmp_path):
    ready = tmp_path / "ready-port"
    config = {
        "SECRET_KEY": KEY,
        "SQLITE_DATABASE_PATH": str(tmp_path / "chat.db"),
        "CHAT_MEDIA_DIR": str(tmp_path / "media"),
        "COPY_SEED_DATABASE": False,
    }
    code = """
import json, os
from pathlib import Path
from werkzeug.serving import make_server
from app import create_app
app = create_app(json.loads(os.environ["CHAT_TEST_CONFIG"]))
server = make_server("127.0.0.1", 0, app)
Path(os.environ["CHAT_TEST_READY"]).write_text(str(server.server_port))
server.serve_forever()
"""
    service_dir = Path(__file__).resolve().parents[2] / "recommendation-service"
    process = subprocess.Popen(
        [sys.executable, "-c", code],
        cwd=service_dir,
        env={
            **os.environ,
            "PYTHONPATH": str(service_dir),
            "CHAT_TEST_CONFIG": json.dumps(config),
            "CHAT_TEST_READY": str(ready),
            "PYTHONDONTWRITEBYTECODE": "1",
        },
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        deadline = time.monotonic() + 15
        while not ready.exists():
            if process.poll() is not None:
                pytest.fail("Recommendation service did not start: " + process.stderr.read())
            if time.monotonic() > deadline:
                pytest.fail("Timed out starting the isolated recommendation service")
            time.sleep(0.05)
        port = int(ready.read_text())
        with patch("app.routes.RECOMMENDATION_SERVICE_URL", f"http://127.0.0.1:{port}"):
            application = create_app()
            application.config["TESTING"] = True
            yield application
    finally:
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
        process.stderr.close()


def test_two_accounts_share_messages_and_media_through_real_http(gateway):
    alice = gateway.test_client()
    bob = gateway.test_client()
    guest = gateway.test_client()
    text = alice.post(
        "/chat/messages", json={"message": "Hello \U0001f60a"}, headers=_auth("alice"),
    )
    assert text.status_code == 201
    assert bob.get("/chat/messages").json[0]["message"] == "Hello \U0001f60a"
    assert bob.delete("/chat/messages/" + text.json["id"], headers=_auth("bob")).status_code == 403
    sticker = bob.post(
        "/chat/messages",
        json={"message": "", "media_type": "sticker", "media_url": "\U0001f389 Shared sticker"},
        headers=_auth("bob"),
    )
    assert sticker.status_code == 201
    video = b"\x00\x00\x00\x18ftypisom\x00\x00\x00\x00isommp42"
    uploaded = alice.post(
        "/chat/uploads",
        data={"file": (io.BytesIO(video), "clip.mp4", "application/octet-stream")},
        headers=_auth("alice"),
    )
    assert uploaded.status_code == 201
    message = alice.post(
        "/chat/messages", json={"message": "Video", **uploaded.json}, headers=_auth("alice"),
    )
    assert message.status_code == 201
    feed = guest.get("/chat/messages").json
    assert [item["id"] for item in feed] == [text.json["id"], sticker.json["id"], message.json["id"]]
    media_url = feed[-1]["media_url"]
    with bob.get(media_url, headers={"Range": "bytes=0-7"}) as part:
        assert part.status_code == 206
        assert part.data == video[:8]
        assert part.headers["Content-Range"] == f"bytes 0-7/{len(video)}"
        assert part.mimetype == "video/mp4"
    with guest.head(media_url) as head:
        assert head.status_code == 200
        assert head.headers["Content-Length"] == str(len(video))
    assert guest.post("/chat/messages", json={"message": "No sign-in"}).status_code == 401
    assert alice.delete("/chat/messages/" + text.json["id"], headers=_auth("alice")).status_code == 200
    assert len(bob.get("/chat/messages").json) == 2
