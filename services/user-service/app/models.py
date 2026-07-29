"""user-service/models.py

SQLite database models for the User Service.
Owns: users table (id, username, password_hash, preferences, created_at)
"""
import os
import sqlite3
import uuid
import datetime


def get_db_path(app=None):
    """Get the database path from app config or default."""
    if app:
        return app.config["DATABASE"]
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
    """Create the users table if it doesn't exist."""
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
        (user_id, username, password_hash, str(preferences), created_at)
    )
    conn.commit()
    conn.close()
    return {"id": user_id, "username": username, "preferences": preferences, "created_at": created_at}

