"""user-service/models.py

SQLite database models for the User Service.
Owns: users table (id, username, password_hash, preferences, created_at)
Owns: favorites table (id, user_id, destination_name, created_at)
"""
import os
import sqlite3
import uuid
import datetime
import json

from flask import current_app


def get_db_path(app=None):
    """Get the database path from app config or default."""
    if app:
        return app.config["DATABASE"]
    try:
        return current_app.config["DATABASE"]
    except RuntimeError:
        return os.environ.get(
            "DATABASE_PATH",
            os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "database", "users.db")
        )


def get_connection(app=None):
    """Get a SQLite connection."""
    db_path = get_db_path(app)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db(app=None):
    """Create the users and favorites tables if they don't exist."""
    conn = get_connection(app)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            preferences TEXT DEFAULT '[]',
            created_at TEXT NOT NULL
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS favorites (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            destination_name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            UNIQUE(user_id, destination_name),
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    """)
    conn.commit()
    conn.close()


def get_user_by_username(username, app=None):
    """Return a user dict by username, or None."""
    conn = get_connection(app)
    cursor = conn.execute("SELECT * FROM users WHERE username = ?", (username,))
    row = cursor.fetchone()
    conn.close()
    if row:
        return dict(row)
    return None


def get_user_by_id(user_id, app=None):
    """Return a user dict by ID, or None."""
    conn = get_connection(app)
    cursor = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,))
    row = cursor.fetchone()
    conn.close()
    if row:
        return dict(row)
    return None


def create_user(username, password_hash, preferences, app=None):
    """Insert a new user into the database."""
    user_id = str(uuid.uuid4())
    created_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
    conn = get_connection(app)
    conn.execute(
        "INSERT INTO users (id, username, password_hash, preferences, created_at) VALUES (?, ?, ?, ?, ?)",
        (user_id, username, password_hash, json.dumps(preferences), created_at)
    )
    conn.commit()
    conn.close()
    return {"id": user_id, "username": username, "preferences": preferences, "created_at": created_at}

def get_favorites_for_user(username, app=None):
    """Return the list of favorite destination names for a given username."""
    user = get_user_by_username(username, app)
    if not user:
        return []
    conn = get_connection(app)
    cursor = conn.execute(
        "SELECT destination_name FROM favorites WHERE user_id = ? ORDER BY created_at DESC",
        (user["id"],),
    )
    rows = cursor.fetchall()
    conn.close()
    return [row["destination_name"] for row in rows]


def toggle_favorite_for_user(username, destination_name, app=None):
    """Toggle a favorite destination for a user and return an updated list."""
    user = get_user_by_username(username, app)
    if not user:
        raise ValueError("user not found")

    destination_name = destination_name.strip()
    if destination_name == "":
        raise ValueError("destination is required")

    conn = get_connection(app)
    cursor = conn.execute(
        "SELECT id FROM favorites WHERE user_id = ? AND destination_name = ?",
        (user["id"], destination_name),
    )
    existing = cursor.fetchone()

    if existing:
        conn.execute(
            "DELETE FROM favorites WHERE id = ?",
            (existing["id"],),
        )
    else:
        favorite_id = str(uuid.uuid4())
        created_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        conn.execute(
            "INSERT INTO favorites (id, user_id, destination_name, created_at) VALUES (?, ?, ?, ?)",
            (favorite_id, user["id"], destination_name, created_at),
        )

    conn.commit()
    conn.close()
    return get_favorites_for_user(username, app)


def get_preferences_for_user(username, app=None):
    """Return (preferences, favorites) for a username, or ([], []) if unknown.

    This is the data contract consumed by the Recommendation Service's
    scoring engine (recommendations.py) via the internal endpoint.
    """
    user = get_user_by_username(username, app)
    if not user:
        return [], []

    try:
        prefs = (
            json.loads(user["preferences"])
            if isinstance(user["preferences"], str)
            else user["preferences"]
        )
    except (json.JSONDecodeError, TypeError):
        prefs = []

    favorites = get_favorites_for_user(username, app)
    return prefs or [], favorites or []
