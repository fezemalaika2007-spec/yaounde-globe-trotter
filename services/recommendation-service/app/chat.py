"""Shared community messages and persistent, same-origin media."""
import re
import sqlite3
import uuid
from pathlib import Path

from flask import Blueprint, abort, current_app, g, jsonify, request, send_file
from werkzeug.exceptions import HTTPException

from app.auth_middleware import token_required
from app.models import (
    chat_transaction, create_chat_message, delete_chat_message,
    get_chat_message, get_chat_messages, update_chat_message,
)

chat_bp = Blueprint("chat", __name__)
MAX_MEDIA_BYTES = 20 * 1024 * 1024
_MEDIA_PREFIX = "/chat/media/"
_FILENAME = re.compile(r"[0-9a-f]{32}\.(?:jpg|png|gif|webp|mp4|webm)")


@chat_bp.errorhandler(HTTPException)
def http_error(error):
    return jsonify({"error": error.description}), error.code


@chat_bp.errorhandler(sqlite3.Error)
def database_error(error):
    current_app.logger.exception("Community chat database operation failed")
    return jsonify({"error": "Chat storage is unavailable. Please try again."}), 503


@chat_bp.errorhandler(OSError)
def storage_error(error):
    current_app.logger.exception("Community media storage operation failed")
    return jsonify({"error": "Media storage is unavailable. Please try again."}), 503


def _body():
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        abort(400, description="A JSON object is required")
    return body


def _text(body, key):
    value = body.get(key, "")
    if not isinstance(value, str):
        abort(400, description=f"{key} must be text")
    return value.strip()


def _owned_message(msg_id):
    message = get_chat_message(msg_id)
    if message is None:
        abort(404, description="Message not found")
    if message["user_id"] != g.current_user:
        abort(403, description="Only the sender can change this message")
    return message


def _upload(filename):
    if not _FILENAME.fullmatch(filename):
        abort(404, description="Attachment not found")
    with chat_transaction() as cur:
        cur.execute(
            "SELECT user_id, media_type, content_type FROM chat_uploads WHERE filename = %s",
            (filename,),
        )
        upload = cur.fetchone()
    root = Path(current_app.config["CHAT_MEDIA_DIR"]).resolve()
    path = root / filename
    if upload is None or path.resolve().parent != root or not path.is_file():
        abort(404, description="Attachment not found")
    return upload, path


def _media_format(content):
    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png", "image/png", "image"
    if content.startswith(b"\xff\xd8\xff"):
        return "jpg", "image/jpeg", "image"
    if content.startswith((b"GIF87a", b"GIF89a")):
        return "gif", "image/gif", "image"
    if content.startswith(b"RIFF") and content[8:12] == b"WEBP":
        return "webp", "image/webp", "image"
    if (content.startswith(b"\x1a\x45\xdf\xa3")
            and b"webm" in content[:4096]):
        return "webm", "video/webm", "video"
    if len(content) >= 16 and content[4:8] == b"ftyp":
        brands = {
            b"isom", b"iso2", b"iso3", b"iso4", b"iso5", b"iso6",
            b"mp41", b"mp42", b"avc1", b"M4V ", b"dash",
        }
        box_size = int.from_bytes(content[:4], "big")
        if 16 <= box_size <= len(content) and content[8:12] in brands:
            return "mp4", "video/mp4", "video"
    abort(415, description="Choose a JPEG, PNG, GIF, WebP, MP4, or WebM file")


@chat_bp.route("/chat/messages", methods=["GET"])
def list_messages():
    raw_limit = request.args.get("limit", "100")
    try:
        limit = int(raw_limit)
    except ValueError:
        abort(400, description="limit must be a positive integer")
    if limit < 1:
        abort(400, description="limit must be a positive integer")
    response = jsonify(get_chat_messages(limit=min(limit, 100)))
    response.headers["Cache-Control"] = "no-store"
    return response


@chat_bp.route("/chat/messages", methods=["POST", "OPTIONS"])
@token_required
def send_message():
    if request.method == "OPTIONS":
        return jsonify({})
    body = _body()
    text = _text(body, "message")
    media_url = _text(body, "media_url")
    media_type = _text(body, "media_type")
    reply_id = _text(body, "reply_to_id")
    if not text and not media_url:
        abort(400, description="Message content or a media attachment is required")
    if media_type == "sticker":
        if not media_url or len(media_url) > 1000:
            abort(400, description="A sticker label of up to 1000 characters is required")
    elif media_url:
        if not media_url.startswith(_MEDIA_PREFIX):
            abort(400, description="Upload the attachment before sending the message")
        upload, _ = _upload(media_url[len(_MEDIA_PREFIX):])
        if upload[0] != g.current_user:
            abort(403, description="Use an attachment uploaded by your account")
        if media_type != upload[1]:
            abort(400, description="Attachment type does not match the uploaded file")
    elif media_type:
        abort(400, description="An attachment is required for this media type")
    reply = get_chat_message(reply_id) if reply_id else None
    if reply_id and reply is None:
        abort(400, description="The message you are replying to no longer exists")
    message = create_chat_message(
        user_id=g.current_user,
        username=g.current_user,
        message=text,
        media_url=media_url,
        media_type=media_type,
        reply_to_id=reply_id,
        reply_to_username=reply["username"] if reply else "",
        reply_to_message=reply["message"] if reply else "",
    )
    return jsonify(message), 201


@chat_bp.route("/chat/messages/<msg_id>", methods=["PUT", "DELETE", "OPTIONS"])
@token_required
def message_detail(msg_id):
    if request.method == "OPTIONS":
        return jsonify({})
    _owned_message(msg_id)
    if request.method == "DELETE":
        changed = delete_chat_message(msg_id, g.current_user)
    else:
        text = _text(_body(), "message")
        if not text:
            abort(400, description="Message content cannot be empty")
        changed = update_chat_message(msg_id, g.current_user, text)
    if not changed:
        abort(404, description="Message not found")
    return jsonify({"success": True})


@chat_bp.route("/chat/uploads", methods=["POST", "OPTIONS"])
@token_required
def upload_media():
    if request.method == "OPTIONS":
        return jsonify({})
    files = request.files.getlist("file")
    if len(files) != 1 or len(request.files) != 1:
        abort(400, description="Choose one photo or video")
    file = files[0]
    content = file.stream.read(MAX_MEDIA_BYTES + 1)
    if not content:
        abort(400, description="The attachment is empty")
    if len(content) > MAX_MEDIA_BYTES:
        abort(413, description="Photos and videos must be 20 MB or smaller")
    extension, content_type, media_type = _media_format(content)
    if file.mimetype not in ("", "application/octet-stream", content_type):
        abort(415, description="The declared file type does not match its contents")
    filename = f"{uuid.uuid4().hex}.{extension}"
    path = Path(current_app.config["CHAT_MEDIA_DIR"]) / filename
    output = path.open("xb")
    try:
        with output:
            output.write(content)
        with chat_transaction() as cur:
            cur.execute(
                "INSERT INTO chat_uploads (filename, user_id, media_type, content_type) "
                "VALUES (%s, %s, %s, %s)",
                (filename, g.current_user, media_type, content_type),
            )
    except (OSError, sqlite3.Error):
        path.unlink(missing_ok=True)
        raise
    return jsonify({
        "media_url": f"{_MEDIA_PREFIX}{filename}",
        "media_type": media_type,
    }), 201


@chat_bp.route("/chat/media/<filename>", methods=["GET"])
def read_media(filename):
    upload, path = _upload(filename)
    response = send_file(
        path, mimetype=upload[2], download_name=filename,
        conditional=True, max_age=86400,
    )
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response
