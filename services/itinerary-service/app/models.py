"""itinerary-service/models.py

PostgreSQL database models for the Itinerary Service.
Owns: itineraries table (id, user_id, username, title, destinations, start_date, end_date, notes, created_at)
"""
import os
import uuid
import datetime
import json

import psycopg2
from psycopg2.pool import ThreadedConnectionPool

_pool = None


def _get_database_url(app=None):
    """Return the PostgreSQL connection string from env or app config."""
    if app and app.config.get("DATABASE"):
        return app.config["DATABASE"]
    url = os.environ.get("DATABASE_URL", "")
    if not url:
        raise RuntimeError(
            "DATABASE_URL environment variable is required to connect to "
            "the online PostgreSQL database."
        )
    return url


def get_connection(app=None):
    """Get a PostgreSQL connection from the connection pool or create fallback."""
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
    """Release a connection back to the pool."""
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
    """Create the itineraries table and indexes if they don't exist."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS itineraries (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            username TEXT NOT NULL,
            title TEXT NOT NULL,
            destinations TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            notes TEXT DEFAULT '',
            created_at TEXT NOT NULL
        )
    """)
    cur.execute("CREATE INDEX IF NOT EXISTS idx_itineraries_username ON itineraries(username)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_itineraries_user_id ON itineraries(user_id)")
    conn.commit()
    cur.close()
    release_connection(conn)


def get_itineraries_for_user(username, app=None):
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("SELECT * FROM itineraries WHERE username = %s ORDER BY created_at DESC", (username,))
    rows = cur.fetchall()
    results = [_row_to_dict(r, cur) for r in rows]
    cur.close()
    release_connection(conn)
    return results


def get_itineraries_by_user_id(user_id, app=None):
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("SELECT * FROM itineraries WHERE user_id = %s ORDER BY created_at DESC", (user_id,))
    rows = cur.fetchall()
    results = [_row_to_dict(r, cur) for r in rows]
    cur.close()
    release_connection(conn)
    return results


def get_itinerary_by_id(itinerary_id, app=None):
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("SELECT * FROM itineraries WHERE id = %s", (itinerary_id,))
    row = cur.fetchone()
    result = _row_to_dict(row, cur) if row else None
    cur.close()
    release_connection(conn)
    return result


def create_itinerary(username, user_id, title, destinations, start_date, end_date, notes, app=None):
    itinerary_id = str(uuid.uuid4())
    created_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO itineraries (id, user_id, username, title, destinations, start_date, end_date, notes, created_at) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
        (itinerary_id, user_id, username, title, json.dumps(destinations), start_date, end_date, notes, created_at)
    )
    conn.commit()
    cur.close()
    release_connection(conn)
    return {
        "id": itinerary_id,
        "username": username,
        "title": title,
        "destinations": destinations,
        "start_date": start_date,
        "end_date": end_date,
        "notes": notes,
        "created_at": created_at,
    }


def update_itinerary(itinerary_id, username, title=None, destinations=None, start_date=None, end_date=None, notes=None, app=None):
    existing = get_itinerary_by_id(itinerary_id, app)
    if not existing or existing.get("username") != username:
        return None

    new_title = title if title is not None else existing.get("title")
    new_dest = json.dumps(destinations) if destinations is not None else json.dumps(existing.get("destinations", []))
    new_start = start_date if start_date is not None else existing.get("start_date")
    new_end = end_date if end_date is not None else existing.get("end_date")
    new_notes = notes if notes is not None else existing.get("notes")

    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("""
        UPDATE itineraries
        SET title = %s, destinations = %s, start_date = %s, end_date = %s, notes = %s
        WHERE id = %s AND username = %s
    """, (new_title, new_dest, new_start, new_end, new_notes, itinerary_id, username))
    conn.commit()
    cur.close()
    release_connection(conn)
    return get_itinerary_by_id(itinerary_id, app)


def delete_itinerary(itinerary_id, username, app=None):
    existing = get_itinerary_by_id(itinerary_id, app)
    if not existing or existing.get("username") != username:
        return False

    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("DELETE FROM itineraries WHERE id = %s AND username = %s", (itinerary_id, username))
    conn.commit()
    cur.close()
    release_connection(conn)
    return True


def _row_to_dict(row, cursor):
    """Convert a psycopg2 row to a dict, parsing JSON columns."""
    if row is None:
        return None
    cols = [d[0] for d in cursor.description]
    d = dict(zip(cols, row))
    if isinstance(d.get("destinations"), str):
        try:
            d["destinations"] = json.loads(d["destinations"])
        except (json.JSONDecodeError, TypeError):
            d["destinations"] = []
    return d
