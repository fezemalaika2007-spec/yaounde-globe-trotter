"""user-service/models.py

PostgreSQL database models for the User Service.
Owns: users table (id, username, password_hash, preferences, created_at)
Owns: favorites table (id, user_id, destination_name, created_at)

The database connection string is read from the DATABASE_URL environment
variable and is never hardcoded.
"""
import os
import uuid
import datetime
import json
from contextlib import contextmanager

import psycopg2
from psycopg2.pool import ThreadedConnectionPool
from flask import current_app

_pool = None

def _get_database_url(app=None):
    """Return the PostgreSQL connection string from env or app config."""
    if app and app.config.get("DATABASE"):
        return app.config["DATABASE"]
    try:
        return current_app.config["DATABASE"]
    except RuntimeError:
        url = os.environ.get("DATABASE_URL", "")
        if not url:
            raise RuntimeError(
                "DATABASE_URL environment variable is required to connect to "
                "the online PostgreSQL database."
            )
        return url


def get_connection(app=None):
    """Get a PostgreSQL connection from the connection pool or create a fallback."""
    global _pool
    db_url = _get_database_url(app)
    if _pool is None:
        try:
            _pool = ThreadedConnectionPool(minconn=1, maxconn=15, dsn=db_url)
        except Exception:
            _pool = None
    if _pool:
        try:
            return _pool.getconn()
        except Exception:
            pass
    return psycopg2.connect(db_url, connect_timeout=15)


def release_connection(conn):
    """Release a connection back to the pool if pooling is active."""
    global _pool
    if _pool and conn:
        try:
            _pool.putconn(conn)
            return
        except Exception:
            pass
    if conn:
        try:
            conn.close()
        except Exception:
            pass


def init_db(app=None):
    """Create the users and favorites tables and indexes if they don't exist."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            email TEXT DEFAULT '',
            is_verified BOOLEAN DEFAULT FALSE,
            verification_code TEXT DEFAULT '',
            auth_provider TEXT DEFAULT 'local',
            preferences TEXT DEFAULT '[]',
            created_at TEXT NOT NULL
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS favorites (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            destination_name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            UNIQUE(user_id, destination_name),
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    """)
    cur.execute("CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id)")
    
    # Ensure the new columns exist (safe migration for existing DBs).
    cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name='users'")
    existing_cols = {r[0] for r in cur.fetchall()}
    col_sql = {
        "email": "ALTER TABLE users ADD COLUMN email TEXT DEFAULT ''",
        "is_verified": "ALTER TABLE users ADD COLUMN is_verified BOOLEAN DEFAULT FALSE",
        "verification_code": "ALTER TABLE users ADD COLUMN verification_code TEXT DEFAULT ''",
        "auth_provider": "ALTER TABLE users ADD COLUMN auth_provider TEXT DEFAULT 'local'",
        "reset_code": "ALTER TABLE users ADD COLUMN reset_code TEXT DEFAULT ''",
        "reset_expires": "ALTER TABLE users ADD COLUMN reset_expires TEXT DEFAULT ''",
    }
    for col, sql in col_sql.items():
        if col not in existing_cols:
            cur.execute(sql)
    conn.commit()
    cur.close()
    release_connection(conn)



def get_user_by_username(username, app=None):
    """Return a user dict by username, or None."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("SELECT * FROM users WHERE username = %s", (username,))
    row = cur.fetchone()
    result = _row_to_dict(row, cur) if row else None
    cur.close()
    release_connection(conn)
    return result


def get_user_by_id(user_id, app=None):
    """Return a user dict by ID, or None."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("SELECT * FROM users WHERE id = %s", (user_id,))
    row = cur.fetchone()
    result = _row_to_dict(row, cur) if row else None
    cur.close()
    release_connection(conn)
    return result


def create_user(username, password_hash, preferences, app=None):
    """Insert a new user into the database."""
    user_id = str(uuid.uuid4())
    created_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO users (id, username, password_hash, preferences, created_at) VALUES (%s, %s, %s, %s, %s)",
        (user_id, username, password_hash, json.dumps(preferences), created_at)
    )
    conn.commit()
    cur.close()
    release_connection(conn)
    return {"id": user_id, "username": username, "preferences": preferences, "created_at": created_at}


def get_user_by_email(email, app=None):
    """Return a user dict by email, or None."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("SELECT * FROM users WHERE email = %s", (email,))
    row = cur.fetchone()
    result = _row_to_dict(row, cur) if row else None
    cur.close()
    release_connection(conn)
    return result


def create_user_with_email(
    username, password_hash, email, preferences,
    verification_code="", app=None
):
    """Create a local user with an email and verification code.

    The user starts as unverified (is_verified=False) until they confirm
    their email with the verification code.
    """
    user_id = str(uuid.uuid4())
    created_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO users (id, username, password_hash, email, is_verified, "
        "verification_code, auth_provider, preferences, created_at) "
        "VALUES (%s, %s, %s, %s, %s, %s, 'local', %s, %s)",
        (
            user_id, username, password_hash, email, False, verification_code,
            json.dumps(preferences), created_at,
        ),
    )
    conn.commit()
    cur.close()
    release_connection(conn)
    return {
        "id": user_id,
        "username": username,
        "email": email,
        "is_verified": False,
        "preferences": preferences,
        "created_at": created_at,
    }


def create_google_user(username, email, preferences, app=None):
    """Create (or return existing) a user authenticated via Google.

    Google users are automatically verified (their email is already
    confirmed by Google). Returns the user dict.
    """
    existing = get_user_by_email(email, app)
    if existing:
        return existing
    user_id = str(uuid.uuid4())
    created_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO users (id, username, password_hash, email, is_verified, "
        "verification_code, auth_provider, preferences, created_at) "
        "VALUES (%s, %s, '', %s, TRUE, '', 'google', %s, %s)",
        (
            user_id, username, email, json.dumps(preferences), created_at,
        ),
    )
    conn.commit()
    cur.close()
    release_connection(conn)
    return {
        "id": user_id,
        "username": username,
        "email": email,
        "is_verified": True,
        "preferences": preferences,
        "created_at": created_at,
    }


def set_verification_code(username, code, app=None):
    """Store a verification code for a username (for email verification)."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "UPDATE users SET verification_code = %s WHERE username = %s",
        (code, username),
    )
    conn.commit()
    cur.close()
    release_connection(conn)


def verify_user(username, code, app=None):
    """Mark a user as verified if the code matches.

    Returns True on success, False if the code is wrong or user not found.
    """
    user = get_user_by_username(username, app)
    if not user:
        return False
    if user.get("verification_code") != code:
        return False
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "UPDATE users SET is_verified = TRUE, verification_code = '' "
        "WHERE username = %s",
        (username,),
    )
    conn.commit()
    cur.close()
    release_connection(conn)
    return True


def get_favorites_for_user(username, app=None):
    """Return the list of favorite destination names for a given username."""
    user = get_user_by_username(username, app)
    if not user:
        return []
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "SELECT destination_name FROM favorites WHERE user_id = %s ORDER BY created_at DESC",
        (user["id"],),
    )
    rows = cur.fetchall()
    cur.close()
    release_connection(conn)
    return [row[0] for row in rows]


def toggle_favorite_for_user(username, destination_name, app=None):
    """Toggle a favorite destination for a user and return an updated list."""
    user = get_user_by_username(username, app)
    if not user:
        raise ValueError("user not found")

    destination_name = destination_name.strip()
    if destination_name == "":
        raise ValueError("destination is required")

    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "SELECT id FROM favorites WHERE user_id = %s AND destination_name = %s",
        (user["id"], destination_name),
    )
    existing = cur.fetchone()

    if existing:
        cur.execute(
            "DELETE FROM favorites WHERE id = %s",
            (existing[0],),
        )
    else:
        favorite_id = str(uuid.uuid4())
        created_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        cur.execute(
            "INSERT INTO favorites (id, user_id, destination_name, created_at) VALUES (%s, %s, %s, %s)",
            (favorite_id, user["id"], destination_name, created_at),
        )

    conn.commit()
    cur.close()
    release_connection(conn)
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


def get_user_by_username_or_email(identifier, app=None):
    """Return a user dict by username or email, or None."""
    if not identifier:
        return None
    identifier = identifier.strip()
    user = get_user_by_username(identifier, app)
    if user:
        return user
    return get_user_by_email(identifier, app)


def set_reset_code(identifier, code, expires_at_iso, app=None):
    """Store a password reset code for a username or email."""
    user = get_user_by_username_or_email(identifier, app)
    if not user:
        return False
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "UPDATE users SET reset_code = %s, reset_expires = %s WHERE id = %s",
        (code, expires_at_iso, user["id"]),
    )
    conn.commit()
    cur.close()
    release_connection(conn)
    return True


def verify_reset_code_and_update_password(identifier, code, new_password_hash, app=None):
    """Verify the reset code and update the user's password.

    Returns True on success, False if code is invalid or expired.
    """
    user = get_user_by_username_or_email(identifier, app)
    if not user:
        return False
    if not user.get("reset_code") or user.get("reset_code") != code:
        return False

    expires_str = user.get("reset_expires", "")
    if expires_str:
        try:
            expires = datetime.datetime.fromisoformat(expires_str)
            now = datetime.datetime.now(datetime.timezone.utc)
            if now > expires:
                return False
        except ValueError:
            pass

    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "UPDATE users SET password_hash = %s, reset_code = '', reset_expires = '' WHERE id = %s",
        (new_password_hash, user["id"]),
    )
    conn.commit()
    cur.close()
    conn.close()
    return True


def _row_to_dict(row, cursor):
    """Convert a psycopg2 row to a dict."""
    if row is None:
        return None
    cols = [d[0] for d in cursor.description]
    return dict(zip(cols, row))
