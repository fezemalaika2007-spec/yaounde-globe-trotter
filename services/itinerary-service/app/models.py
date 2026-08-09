"""itinerary-service/models.py

PostgreSQL database models for the Itinerary Service.
Owns: itineraries table (id, user_id, title, destinations, start_date, end_date, notes, created_at)

The database connection string is read from the DATABASE_URL environment
variable and is never hardcoded.
"""
import os
import uuid
import datetime
import json

import psycopg2


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
    """Get a PostgreSQL connection."""
    return psycopg2.connect(_get_database_url(app), connect_timeout=15)


def init_db(app=None):
    """Create the itineraries table if it doesn't exist."""
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
    conn.commit()
    cur.close()
    conn.close()


def get_itineraries_for_user(username, app=None):
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("SELECT * FROM itineraries WHERE username = %s ORDER BY created_at DESC", (username,))
    rows = cur.fetchall()
    results = [_row_to_dict(r, cur) for r in rows]
    cur.close()
    conn.close()
    return results


def get_itineraries_by_user_id(user_id, app=None):
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("SELECT * FROM itineraries WHERE user_id = %s ORDER BY created_at DESC", (user_id,))
    rows = cur.fetchall()
    results = [_row_to_dict(r, cur) for r in rows]
    cur.close()
    conn.close()
    return results


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
    conn.close()
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
