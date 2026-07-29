"""itinerary-service/models.py

SQLite database models for the Itinerary Service.
Owns: itineraries table (id, user_id, title, destinations, start_date, end_date, notes, created_at)
"""
import os
import sqlite3
import uuid
import datetime


def get_db_path(app=None):
    if app:
        return app.config["DATABASE"]
    return os.environ.get(
        "DATABASE_PATH",
        os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "database", "itineraries.db")
    )


def get_connection(app=None):
    db_path = get_db_path(app)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db(app=None):
    conn = get_connection(app)
    conn.execute("""
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
    conn.close()


def get_itineraries_for_user(username, app=None):
    conn = get_connection(app)
    cursor = conn.execute("SELECT * FROM itineraries WHERE username = ? ORDER BY created_at DESC", (username,))
    rows = cursor.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_itineraries_by_user_id(user_id, app=None):
    conn = get_connection(app)
    cursor = conn.execute("SELECT * FROM itineraries WHERE user_id = ? ORDER BY created_at DESC", (user_id,))
    rows = cursor.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def create_itinerary(username, user_id, title, destinations, start_date, end_date, notes, app=None):
    import json
    itinerary_id = str(uuid.uuid4())
    created_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
    conn = get_connection(app)
    conn.execute(
        "INSERT INTO itineraries (id, user_id, username, title, destinations, start_date, end_date, notes, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (itinerary_id, user_id, username, title, json.dumps(destinations), start_date, end_date, notes, created_at)
    )
    conn.commit()
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

