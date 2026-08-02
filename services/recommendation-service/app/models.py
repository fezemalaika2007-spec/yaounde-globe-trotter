"""recommendation-service/models.py

SQLite database models for the Recommendation Service.
Owns:
  - destinations table (id, osm_id, name, area, tags, description, cost,
    image, image_source, average_rating, rating_count, last_synced_at)
  - ratings table (id, destination_id, user_id, rating, created_at)

Destinations are sourced from OpenStreetMap Overpass API and periodically
refreshed. Ratings are keyed by destination_id which is derived from the
stable OSM element ID (osm_id), not the row's primary key, so ratings
persist correctly across Overpass re-syncs.
"""
import os
import sqlite3
import uuid
import datetime
import json


def get_db_path(app=None):
    if app:
        return app.config["DATABASE"]
    return os.environ.get(
        "DATABASE_PATH",
        os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "database", "recommendations.db")
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
    # Destinations table — osm_id is the stable OSM element identifier
    conn.execute("""
        CREATE TABLE IF NOT EXISTS destinations (
            id TEXT PRIMARY KEY,
            osm_id TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            area TEXT DEFAULT '',
            tags TEXT DEFAULT '[]',
            description TEXT DEFAULT '',
            cost REAL,
            image TEXT DEFAULT '',
            image_source TEXT DEFAULT 'placeholder',
            average_rating REAL DEFAULT 0.0,
            rating_count INTEGER DEFAULT 0,
            last_synced_at TEXT
        )
    """)
    # Ratings table — one rating per user per destination (upsert)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS ratings (
            id TEXT PRIMARY KEY,
            destination_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            rating INTEGER NOT NULL CHECK(rating >= 1 AND rating <= 5),
            created_at TEXT NOT NULL,
            UNIQUE(destination_id, user_id)
        )
    """)
    
    # Migrations to add new columns to destinations table if they don't exist
    new_columns = [
        ("latitude", "REAL"),
        ("longitude", "REAL"),
        ("address", "TEXT DEFAULT ''"),
        ("category", "TEXT DEFAULT ''"),
        ("activities", "TEXT DEFAULT '[]'"),
        ("opening_hours", "TEXT DEFAULT ''"),
        ("phone", "TEXT DEFAULT ''"),
        ("website", "TEXT DEFAULT ''"),
        ("email", "TEXT DEFAULT ''"),
        ("price_level", "INTEGER"),
        ("facilities", "TEXT DEFAULT '[]'"),
        ("cuisine", "TEXT DEFAULT ''"),
        ("star_rating", "REAL"),
        ("images", "TEXT DEFAULT '[]'")
        ,("long_description", "TEXT DEFAULT ''")
    ]
    
    for col_name, col_type in new_columns:
        try:
            conn.execute(f"ALTER TABLE destinations ADD COLUMN {col_name} {col_type}")
        except sqlite3.OperationalError:
            # Column already exists
            pass
            
    conn.commit()
    conn.close()


# ---------------------------------------------------------------------------
# Destination helpers
# ---------------------------------------------------------------------------

def get_all_destinations(app=None):
    """Return all destinations."""
    conn = get_connection(app)
    cursor = conn.execute("SELECT * FROM destinations ORDER BY name ASC")
    rows = cursor.fetchall()
    conn.close()
    results = []
    for r in rows:
        d = dict(r)
        for key in ["tags", "activities", "facilities", "images"]:
            if key in d and isinstance(d[key], str):
                try:
                    d[key] = json.loads(d[key])
                except (json.JSONDecodeError, TypeError):
                    d[key] = []
        results.append(d)
    return results


def get_destination_by_id(dest_id, app=None):
    """Return a single destination by its primary key."""
    conn = get_connection(app)
    cursor = conn.execute("SELECT * FROM destinations WHERE id = ?", (dest_id,))
    row = cursor.fetchone()
    conn.close()
    if row:
        d = dict(row)
        for key in ["tags", "activities", "facilities", "images"]:
            if key in d and isinstance(d[key], str):
                try:
                    d[key] = json.loads(d[key])
                except (json.JSONDecodeError, TypeError):
                    d[key] = []
        return d
    return None


def get_destination_by_osm_id(osm_id, app=None):
    """Return a destination by its stable OSM element ID."""
    conn = get_connection(app)
    cursor = conn.execute("SELECT * FROM destinations WHERE osm_id = ?", (osm_id,))
    row = cursor.fetchone()
    conn.close()
    if row:
        d = dict(row)
        for key in ["tags", "activities", "facilities", "images"]:
            if key in d and isinstance(d[key], str):
                try:
                    d[key] = json.loads(d[key])
                except (json.JSONDecodeError, TypeError):
                    d[key] = []
        return d
    return None


def upsert_destination(
    osm_id, name, area, tags, description, cost, image, image_source,
    latitude=None, longitude=None, address='', category='', activities=None,
    opening_hours='', phone='', website='', email='', price_level=None,
    facilities=None, cuisine='', star_rating=None, images=None, long_description='', app=None
):
    """Insert or update a destination by osm_id (stable OSM identifier)."""
    conn = get_connection(app)
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    # Defaults for list parameters
    activities_val = activities if activities is not None else []
    facilities_val = facilities if facilities is not None else []
    images_val = images if images is not None else []

    # Check if destination already exists
    existing = conn.execute("SELECT * FROM destinations WHERE osm_id = ?", (osm_id,)).fetchone()

    if existing:
        existing_dict = dict(existing)
        conn.execute("""
            UPDATE destinations SET
                name = ?, area = ?, tags = ?, description = ?, long_description = ?,
                cost = ?, image = ?, image_source = ?, last_synced_at = ?,
                latitude = ?, longitude = ?, address = ?, category = ?,
                activities = ?, opening_hours = ?, phone = ?, website = ?,
                email = ?, price_level = ?, facilities = ?, cuisine = ?,
                star_rating = ?, images = ?
            WHERE osm_id = ?
        """, (
            name, area, json.dumps(tags), description, long_description,
            cost, image, image_source, now,
            latitude, longitude, address, category,
            json.dumps(activities_val), opening_hours, phone, website,
            email, price_level, json.dumps(facilities_val), cuisine,
            star_rating, json.dumps(images_val), osm_id
        ))
        result_id = existing_dict["id"]
    else:
        dest_id = str(uuid.uuid4())
        conn.execute("""
            INSERT INTO destinations (
                id, osm_id, name, area, tags, description, long_description, cost, image, image_source,
                latitude, longitude, address, category, activities, opening_hours,
                phone, website, email, price_level, facilities, cuisine, star_rating,
                images, average_rating, rating_count, last_synced_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0.0, 0, ?)
        """, (
            dest_id, osm_id, name, area, json.dumps(tags), description, long_description, cost, image, image_source,
            latitude, longitude, address, category, json.dumps(activities_val), opening_hours,
            phone, website, email, price_level, json.dumps(facilities_val), cuisine, star_rating,
            json.dumps(images_val), now
        ))
        result_id = dest_id

    conn.commit()
    conn.close()
    return result_id


def set_last_synced_now(app=None):
    """Set last_synced_at for all destinations to now."""
    conn = get_connection(app)
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    conn.execute("UPDATE destinations SET last_synced_at = ?", (now,))
    conn.commit()
    conn.close()


# ---------------------------------------------------------------------------
# Rating helpers
# ---------------------------------------------------------------------------

def upsert_rating(destination_id, user_id, rating_value, app=None):
    """Create or update a rating. Returns updated average_rating and rating_count."""
    import math
    conn = get_connection(app)
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    # Check existing rating
    existing = conn.execute(
        "SELECT * FROM ratings WHERE destination_id = ? AND user_id = ?",
        (destination_id, user_id)
    ).fetchone()

    if existing:
        # Update existing rating
        conn.execute(
            "UPDATE ratings SET rating = ?, created_at = ? WHERE destination_id = ? AND user_id = ?",
            (rating_value, now, destination_id, user_id)
        )
    else:
        # Insert new rating
        rating_id = str(uuid.uuid4())
        conn.execute(
            "INSERT INTO ratings (id, destination_id, user_id, rating, created_at) VALUES (?, ?, ?, ?, ?)",
            (rating_id, destination_id, user_id, rating_value, now)
        )

    # Recompute average rating and count for this destination
    cursor = conn.execute(
        "SELECT AVG(rating) as avg_r, COUNT(*) as cnt FROM ratings WHERE destination_id = ?",
        (destination_id,)
    )
    stats = cursor.fetchone()
    avg_rating = round(stats["avg_r"], 2) if stats["avg_r"] else 0.0
    count = stats["cnt"] or 0

    conn.execute(
        "UPDATE destinations SET average_rating = ?, rating_count = ? WHERE id = ?",
        (avg_rating, count, destination_id)
    )
    conn.commit()
    conn.close()
    return {"average_rating": avg_rating, "rating_count": count}


def get_user_rating(destination_id, user_id, app=None):
    """Get a specific user's rating for a destination, or None."""
    conn = get_connection(app)
    cursor = conn.execute(
        "SELECT rating FROM ratings WHERE destination_id = ? AND user_id = ?",
        (destination_id, user_id)
    )
    row = cursor.fetchone()
    conn.close()
    return row["rating"] if row else None
