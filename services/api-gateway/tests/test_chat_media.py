"""Transport tests for multipart uploads and streamed video ranges."""
import io
import sys
from pathlib import Path
from unittest.mock import Mock, patch

import pytest
import requests

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import create_app


@pytest.fixture
def client():
    app = create_app()
    app.config["TESTING"] = True
    return app.test_client()


def upstream(content, status=200, headers=None):
    response = Mock()
    response.status_code = status
    response.headers = headers or {"Content-Type": "application/json"}
    response.iter_content.return_value = iter([content])
    return response


def test_upload_keeps_multipart_bytes_boundary_and_authorization(client):
    response = upstream(b'{"media_url":"/chat/media/test.png","media_type":"image"}', 201)
    with patch("app.routes.requests.request", return_value=response) as forward:
        result = client.post(
            "/chat/uploads", data={"file": (io.BytesIO(b"\x00\x80\xff"), "photo.png")},
            headers={"Authorization": "Bearer isolated-test"},
        )
        assert result.status_code == 201
        assert result.json["media_type"] == "image"
        args = forward.call_args.kwargs
        assert args["url"].endswith("/chat/uploads")
        assert args["headers"]["Content-Type"].startswith("multipart/form-data; boundary=")
        assert args["headers"]["Authorization"] == "Bearer isolated-test"
        assert b"\x00\x80\xff" in args["data"]
        assert b'filename="photo.png"' in args["data"]
        assert "json" not in args
        assert args["stream"] is True
        assert args["allow_redirects"] is False
        result.close()
        assert response.close.called


def test_video_range_metadata_and_bytes_are_forwarded(client):
    response = upstream(b"234", 206, {
        "Content-Type": "video/mp4", "Content-Range": "bytes 2-4/10",
        "Accept-Ranges": "bytes", "Content-Length": "3",
        "Cache-Control": "public, max-age=86400", "ETag": '"video"',
    })
    with patch("app.routes.requests.request", return_value=response) as forward:
        result = client.get("/chat/media/test.mp4", headers={"Range": "bytes=2-4"})
        assert result.status_code == 206
        assert result.data == b"234"
        assert result.headers["Content-Range"] == "bytes 2-4/10"
        assert result.headers["Accept-Ranges"] == "bytes"
        assert result.headers["Content-Length"] == "3"
        assert result.mimetype == "video/mp4"
        assert forward.call_args.kwargs["headers"]["Range"] == "bytes=2-4"
        assert forward.call_args.kwargs["headers"]["Accept-Encoding"] == "identity"
        result.close()
        assert response.close.called


def test_head_preserves_size_without_sending_video(client):
    response = upstream(b"", 200, {"Content-Type": "video/webm", "Content-Length": "2048"})
    with patch("app.routes.requests.request", return_value=response) as forward:
        result = client.head("/chat/media/test.webm")
        assert result.status_code == 200
        assert result.data == b""
        assert result.headers["Content-Length"] == "2048"
        assert forward.call_args.kwargs["method"] == "HEAD"
        result.close()
        assert response.close.called


@pytest.mark.parametrize("path", ["/chat/uploads", "/chat/media/test.mp4"])
def test_preflight_allows_uploads_and_range_headers(client, path):
    with patch("app.routes.requests.request") as forward:
        response = client.options(path)
        assert response.status_code == 200
        assert "Range" in response.headers["Access-Control-Allow-Headers"]
        assert "Content-Type" in response.headers["Access-Control-Allow-Headers"]
        forward.assert_not_called()


@pytest.mark.parametrize("error,status", [
    (requests.exceptions.ConnectionError(), 503),
    (requests.exceptions.Timeout(), 504),
])
def test_media_transport_errors_remain_json(client, error, status):
    with patch("app.routes.requests.request", side_effect=error):
        response = client.get("/chat/media/test.mp4")
        assert response.status_code == status
        assert response.is_json


def test_transport_limit_is_enforced_before_forwarding(client):
    with patch("app.routes.requests.request") as forward:
        response = client.post(
            "/chat/uploads", data=b"x", content_type="application/octet-stream",
            environ_overrides={"CONTENT_LENGTH": str(25 * 1024 * 1024 + 1)},
        )
        assert response.status_code == 413
        assert "20 MB" in response.json["error"]
        forward.assert_not_called()
