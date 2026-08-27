"""recommendation-service/models.py

PostgreSQL database models for the Recommendation Service.

Owns:
  - destinations table (id, fsq_id, name, area, tags, description, cost,
    image, image_source, average_rating, rating_count, last_synced_at)
  - ratings table (id, destination_id, user_id, rating, created_at)

Destinations are sourced from the Foursquare Places API and periodically
refreshed. Ratings are keyed by destination_id (the row's primary key).
The database connection string is read from the DATABASE_URL environment
variable and is never hardcoded.
"""
import os
import uuid
import datetime
import json

import psycopg2
import psycopg2.extras
from psycopg2.pool import ThreadedConnectionPool

_pool = None


def _get_database_url(app=None):
    """Return the PostgreSQL connection string from env or app config."""
    url = ""
    if app and app.config.get("DATABASE"):
        url = app.config["DATABASE"]
    if not url:
        url = os.environ.get("DATABASE_URL", "")
    if "-pooler" in url:
        url = url.replace("-pooler", "")
    if not url:
        raise RuntimeError(
            "DATABASE_URL environment variable is required to connect to "
            "the online PostgreSQL database."
        )
    return url


import sqlite3

class SQLiteCursorWrapper:
    def __init__(self, cur):
        self.cur = cur
        self.description = None

    def execute(self, sql, params=()):
        sql = sql.replace("%s", "?")
        if "TRUNCATE destinations" in sql:
            self.cur.execute("DELETE FROM destinations;")
            try:
                self.cur.execute("DELETE FROM ratings;")
            except Exception:
                pass
        else:
            self.cur.execute(sql, params)
        self.description = self.cur.description

    def fetchall(self):
        rows = self.cur.fetchall()
        return [tuple(r) for r in rows]

    def fetchone(self):
        row = self.cur.fetchone()
        return tuple(row) if row else None

    def close(self):
        try:
            self.cur.close()
        except Exception:
            pass


class SQLiteWrapper:
    def __init__(self, db_path=None):
        if db_path is None:
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            db_path = os.path.join(base_dir, "destinations.db")
        self.conn = sqlite3.connect(db_path, check_same_thread=False)

    def cursor(self):
        return SQLiteCursorWrapper(self.conn.cursor())

    def commit(self):
        self.conn.commit()

    def rollback(self):
        try:
            self.conn.rollback()
        except Exception:
            pass

    def close(self):
        try:
            self.conn.close()
        except Exception:
            pass


def get_connection(app=None):
    """Return local SQLite database wrapper as single source of truth."""
    return SQLiteWrapper()


def release_connection(conn):
    """Release a connection back to the pool."""
    global _pool
    if isinstance(conn, SQLiteWrapper):
        conn.close()
        return
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
    """Create the destinations and ratings tables and seed initial data if empty."""
    try:
        conn = get_connection(app)
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS destinations (
                id TEXT PRIMARY KEY,
                fsq_id TEXT UNIQUE,
                osm_id TEXT,
                name TEXT NOT NULL,
                area TEXT DEFAULT '',
                tags TEXT DEFAULT '[]',
                description TEXT DEFAULT '',
                long_description TEXT DEFAULT '',
                cost REAL,
                image TEXT DEFAULT '',
                image_source TEXT DEFAULT '',
                average_rating REAL DEFAULT 0.0,
                rating_count INTEGER DEFAULT 0,
                last_synced_at TEXT,
                latitude REAL,
                longitude REAL,
                address TEXT DEFAULT '',
                category TEXT DEFAULT '',
                activities TEXT DEFAULT '[]',
                opening_hours TEXT DEFAULT '',
                phone TEXT DEFAULT '',
                website TEXT DEFAULT '',
                email TEXT DEFAULT '',
                price_level INTEGER,
                facilities TEXT DEFAULT '[]',
                cuisine TEXT DEFAULT '',
                star_rating REAL,
                images TEXT DEFAULT '[]'
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS ratings (
                id TEXT PRIMARY KEY,
                destination_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                rating INTEGER NOT NULL CHECK(rating >= 1 AND rating <= 5),
                created_at TEXT NOT NULL,
                UNIQUE(destination_id, user_id)
            )
        """)
        cur.execute("CREATE INDEX IF NOT EXISTS idx_destinations_fsq_id ON destinations(fsq_id)")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_ratings_dest_user ON ratings(destination_id, user_id)")

        # --- Notifications table ---
        cur.execute("""
            CREATE TABLE IF NOT EXISTS notifications (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                type TEXT DEFAULT 'info',
                is_read INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                related_id TEXT DEFAULT ''
            )
        """)
        cur.execute("CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id)")

        # --- Comments table ---
        cur.execute("""
            CREATE TABLE IF NOT EXISTS comments (
                id TEXT PRIMARY KEY,
                destination_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                username TEXT NOT NULL,
                text TEXT NOT NULL,
                created_at TEXT NOT NULL,
                parent_id TEXT DEFAULT NULL,
                updated_at TEXT DEFAULT NULL
            )
        """)
        cur.execute("CREATE INDEX IF NOT EXISTS idx_comments_dest ON comments(destination_id)")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_comments_parent ON comments(parent_id)")

        # --- Feedback table ---
        cur.execute("""
            CREATE TABLE IF NOT EXISTS feedback (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                username TEXT NOT NULL,
                category TEXT DEFAULT 'feedback',
                subject TEXT NOT NULL,
                message TEXT NOT NULL,
                created_at TEXT NOT NULL,
                is_resolved INTEGER DEFAULT 0
            )
        """)

        # Ensure the fsq_id column exists (safe migration for existing DBs).
        try:
            cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name='destinations'")
            existing_cols = {r[0] for r in cur.fetchall()}
            if "fsq_id" not in existing_cols:
                cur.execute("ALTER TABLE destinations ADD COLUMN fsq_id TEXT")
        except Exception:
            pass

        # Ensure comments columns parent_id and updated_at exist
        try:
            cur.execute("ALTER TABLE comments ADD COLUMN parent_id TEXT")
        except Exception:
            pass
        try:
            cur.execute("ALTER TABLE comments ADD COLUMN updated_at TEXT")
        except Exception:
            pass

        conn.commit()
        cur.close()
        release_connection(conn)
    except Exception as e:
        print(f"Warning: init_db connection issue: {e}")


def _row_to_dict(row, cursor):
    """Convert a psycopg2 row to a dict, parsing JSON columns."""
    if row is None:
        return None
    cols = [d[0] for d in cursor.description]
    d = dict(zip(cols, row))
    for key in ["tags", "activities", "facilities", "images"]:
        val = d.get(key)
        if isinstance(val, str):
            try:
                d[key] = json.loads(val)
            except (json.JSONDecodeError, TypeError):
                d[key] = []
        elif val is None:
            d[key] = []
    return d


# ---------------------------------------------------------------------------
# Destination helpers
# ---------------------------------------------------------------------------

def get_all_destinations(app=None):
    """Return all destinations."""
    try:
        conn = get_connection(app)
        cur = conn.cursor()
        cur.execute("SELECT * FROM destinations ORDER BY name ASC")
        rows = cur.fetchall()
        results = [_row_to_dict(r, cur) for r in rows]
        cur.close()
        release_connection(conn)
        return results
    except Exception as e:
        print(f"get_all_destinations exception: {e}")
        return []



def get_destination_by_id(dest_id, app=None):
    """Return a single destination by its primary key (id), fsq_id, or name."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM destinations WHERE id = %s OR fsq_id = %s OR name = %s",
        (dest_id, dest_id, dest_id)
    )
    row = cur.fetchone()
    result = _row_to_dict(row, cur)
    cur.close()
    release_connection(conn)
    return result



def get_destination_by_fsq_id(fsq_id, app=None):
    """Return a destination by its Foursquare venue ID."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("SELECT * FROM destinations WHERE fsq_id = %s", (fsq_id,))
    row = cur.fetchone()
    result = _row_to_dict(row, cur)
    cur.close()
    release_connection(conn)
    return result


def upsert_destination(
    osmid=None, name=None, fsq_id=None, area=None, tags=None, description=None,
    cost=None, image=None, image_source=None, latitude=None, longitude=None,
    address='', category='', activities=None, opening_hours='', phone='',
    website='', email='', price_level=None, facilities=None, cuisine='',
    star_rating=None, images=None, long_description='', app=None
):
    """Insert or update a destination by fsq_id.

    The parameter is named `osmid` for backward-compatibility with the old
    sync code, but we store the Foursquare venue id in the `fsq_id` column.
    """
    conn = get_connection(app)
    cur = conn.cursor()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    activities_val = json.dumps(activities if activities is not None else [])
    facilities_val = json.dumps(facilities if facilities is not None else [])
    images_val = json.dumps(images if images is not None else [])

    # Use fsq_id if provided, else fall back to osm_id (legacy).
    lookup_id = fsq_id or osmid

    existing = None
    if lookup_id:
        cur.execute("SELECT id FROM destinations WHERE fsq_id = %s", (lookup_id,))
        existing = cur.fetchone()

    if existing:
        dest_id = existing[0]
        cur.execute("""
            UPDATE destinations SET
                name = %s, area = %s, tags = %s, description = %s,
                long_description = %s, cost = %s, image = %s,
                image_source = %s, last_synced_at = %s, latitude = %s,
                longitude = %s, address = %s, category = %s,
                activities = %s, opening_hours = %s, phone = %s,
                website = %s, email = %s, price_level = %s,
                facilities = %s, cuisine = %s, star_rating = %s,
                images = %s, fsq_id = %s
            WHERE id = %s
        """, (
            name, area, tags, description, long_description, cost, image,
            image_source, now, latitude, longitude, address, category,
            activities_val, opening_hours, phone, website, email,
            price_level, facilities_val, cuisine, star_rating, images_val,
            lookup_id, dest_id
        ))
    else:
        dest_id = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO destinations (
                id, fsq_id, osm_id, name, area, tags, description,
                long_description, cost, image, image_source, latitude,
                longitude, address, category, activities, opening_hours,
                phone, website, email, price_level, facilities, cuisine,
                star_rating, images, average_rating, rating_count,
                last_synced_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                      %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                      0.0, 0, %s)
        """, (
            dest_id, lookup_id, osmid, name, area, tags, description,
            long_description, cost, image, image_source, latitude,
            longitude, address, category, activities_val, opening_hours,
            phone, website, email, price_level, facilities_val, cuisine,
            star_rating, images_val, now
        ))

    conn.commit()
    cur.close()
    release_connection(conn)
    return dest_id


def set_last_synced_now(app=None):
    """Set last_synced_at for all destinations to now."""
    conn = get_connection(app)
    cur = conn.cursor()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    cur.execute("UPDATE destinations SET last_synced_at = %s", (now,))
    conn.commit()
    cur.close()
    release_connection(conn)


# ---------------------------------------------------------------------------
# Rating helpers
# ---------------------------------------------------------------------------

def upsert_rating(destination_id, user_id, rating_value, app=None):
    """Create or update a rating. Returns updated average_rating and rating_count."""
    conn = get_connection(app)
    cur = conn.cursor()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    cur.execute(
        "SELECT id FROM ratings WHERE destination_id = %s AND user_id = %s",
        (destination_id, user_id)
    )
    existing = cur.fetchone()

    if existing:
        cur.execute(
            "UPDATE ratings SET rating = %s, created_at = %s WHERE destination_id = %s AND user_id = %s",
            (rating_value, now, destination_id, user_id)
        )
    else:
        rating_id = str(uuid.uuid4())
        cur.execute(
            "INSERT INTO ratings (id, destination_id, user_id, rating, created_at) VALUES (%s, %s, %s, %s, %s)",
            (rating_id, destination_id, user_id, rating_value, now)
        )

    cur.execute(
        "SELECT AVG(rating) as avg_r, COUNT(*) as cnt FROM ratings WHERE destination_id = %s",
        (destination_id,)
    )
    stats = cur.fetchone()
    avg_rating = round(stats[0], 2) if stats[0] else 0.0
    count = stats[1] or 0

    cur.execute(
        "UPDATE destinations SET average_rating = %s, rating_count = %s WHERE id = %s",
        (avg_rating, count, destination_id)
    )
    conn.commit()
    cur.close()
    release_connection(conn)
    return {"average_rating": avg_rating, "rating_count": count}


def get_user_rating(destination_id, user_id, app=None):
    """Get a specific user's rating for a destination, or None."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "SELECT rating FROM ratings WHERE destination_id = %s AND user_id = %s",
        (destination_id, user_id)
    )
    row = cur.fetchone()
    cur.close()
    release_connection(conn)
    return row[0] if row else None


INITIAL_SEED_DESTINATIONS = []


def clear_all_destinations(app=None):
    """Delete all records from destinations and ratings tables to maintain a clean virgin state."""
    conn = get_connection(app)
    cur = conn.cursor()
    try:
        cur.execute("TRUNCATE destinations, ratings CASCADE")
        conn.commit()
    except Exception as e:
        print(f"Error clearing destinations: {e}")
        conn.rollback()
    finally:
        cur.close()
        release_connection(conn)


def seed_initial_destinations(app=None):
    """No-op seed function ensuring a fresh, empty destination database."""
    pass


# ---------------------------------------------------------------------------
# Notification helpers
# ---------------------------------------------------------------------------

def create_notification(user_id, title, message, notif_type='info', related_id='', app=None):
    """Create a notification for a user."""
    conn = get_connection(app)
    cur = conn.cursor()
    notif_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    cur.execute(
        "INSERT INTO notifications (id, user_id, title, message, type, is_read, created_at, related_id) "
        "VALUES (%s, %s, %s, %s, %s, 0, %s, %s)",
        (notif_id, user_id, title, message, notif_type, now, related_id)
    )
    conn.commit()
    cur.close()
    release_connection(conn)
    return notif_id


def get_notifications_for_user(user_id, limit=50, app=None):
    """Return notifications for a user, newest first."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "SELECT id, user_id, title, message, type, is_read, created_at, related_id "
        "FROM notifications WHERE user_id = %s ORDER BY created_at DESC LIMIT %s",
        (user_id, limit)
    )
    rows = cur.fetchall()
    cols = ['id', 'user_id', 'title', 'message', 'type', 'is_read', 'created_at', 'related_id']
    results = [dict(zip(cols, r)) for r in rows]
    cur.close()
    release_connection(conn)
    return results


def get_unread_notification_count(user_id, app=None):
    """Return the number of unread notifications for a user."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "SELECT COUNT(*) FROM notifications WHERE user_id = %s AND is_read = 0",
        (user_id,)
    )
    row = cur.fetchone()
    cur.close()
    release_connection(conn)
    return row[0] if row else 0


def mark_notification_read(notif_id, user_id, app=None):
    """Mark a single notification as read."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "UPDATE notifications SET is_read = 1 WHERE id = %s AND user_id = %s",
        (notif_id, user_id)
    )
    conn.commit()
    cur.close()
    release_connection(conn)


def mark_all_notifications_read(user_id, app=None):
    """Mark all notifications as read for a user."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "UPDATE notifications SET is_read = 1 WHERE user_id = %s",
        (user_id,)
    )
    conn.commit()
    cur.close()
    release_connection(conn)


# ---------------------------------------------------------------------------
# Comment helpers
# ---------------------------------------------------------------------------

def create_comment(destination_id, user_id, username, text, parent_id=None, app=None):
    """Create a comment or reply on a destination."""
    conn = get_connection(app)
    cur = conn.cursor()
    comment_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    cur.execute(
        "INSERT INTO comments (id, destination_id, user_id, username, text, created_at, parent_id, updated_at) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
        (comment_id, destination_id, user_id, username, text, now, parent_id, None)
    )
    conn.commit()

    # If this is a reply to another comment, send a notification to the parent author
    if parent_id:
        try:
            cur.execute(
                "SELECT user_id, username FROM comments WHERE id = %s",
                (parent_id,)
            )
            parent_row = cur.fetchone()
            if parent_row:
                parent_user_id = parent_row[0]
                if parent_user_id and parent_user_id != user_id:
                    notif_id = str(uuid.uuid4())
                    snippet = text[:50] + ("..." if len(text) > 50 else "")
                    cur.execute(
                        "INSERT INTO notifications (id, user_id, title, message, type, is_read, created_at, related_id) "
                        "VALUES (%s, %s, %s, %s, %s, 0, %s, %s)",
                        (
                            notif_id,
                            parent_user_id,
                            f"New reply from {username}",
                            f"{username} replied: \"{snippet}\"",
                            "comment_reply",
                            now,
                            destination_id,
                        )
                    )
                    conn.commit()
        except Exception as e:
            print(f"Warning: failed to create reply notification: {e}")

    cur.close()
    release_connection(conn)
    return {
        "id": comment_id,
        "destination_id": destination_id,
        "user_id": user_id,
        "username": username,
        "text": text,
        "created_at": now,
        "parent_id": parent_id,
        "updated_at": None,
    }


def get_comments_for_destination(destination_id, app=None):
    """Return all comments for a destination, oldest first (chronological thread)."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "SELECT id, destination_id, user_id, username, text, created_at, parent_id, updated_at "
        "FROM comments WHERE destination_id = %s ORDER BY created_at ASC",
        (destination_id,)
    )
    rows = cur.fetchall()
    cols = ['id', 'destination_id', 'user_id', 'username', 'text', 'created_at', 'parent_id', 'updated_at']
    results = [dict(zip(cols, r)) for r in rows]
    cur.close()
    release_connection(conn)
    return results


def update_comment(comment_id, user_id, text, app=None):
    """Update a comment if it belongs to the user. Returns updated comment dict or None."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "SELECT id, destination_id, user_id, username, created_at, parent_id FROM comments WHERE id = %s AND user_id = %s",
        (comment_id, user_id)
    )
    row = cur.fetchone()
    if not row:
        cur.close()
        release_connection(conn)
        return None

    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    cur.execute(
        "UPDATE comments SET text = %s, updated_at = %s WHERE id = %s",
        (text, now, comment_id)
    )
    conn.commit()
    cur.close()
    release_connection(conn)
    return {
        "id": row[0],
        "destination_id": row[1],
        "user_id": row[2],
        "username": row[3],
        "text": text,
        "created_at": row[4],
        "parent_id": row[5],
        "updated_at": now,
    }


def delete_comment(comment_id, user_id, app=None):
    """Delete a comment and any child replies if it belongs to the user. Returns True if deleted."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "SELECT id FROM comments WHERE id = %s AND user_id = %s",
        (comment_id, user_id)
    )
    row = cur.fetchone()
    if not row:
        cur.close()
        release_connection(conn)
        return False
    # Delete child replies as well
    cur.execute("DELETE FROM comments WHERE parent_id = %s", (comment_id,))
    cur.execute("DELETE FROM comments WHERE id = %s", (comment_id,))
    conn.commit()
    cur.close()
    release_connection(conn)
    return True


# ---------------------------------------------------------------------------
# Feedback helpers
# ---------------------------------------------------------------------------

ADMIN_USERNAME = "jbc"


def create_feedback(user_id, username, category, subject, message, app=None):
    """Create a feedback/bug report entry."""
    conn = get_connection(app)
    cur = conn.cursor()
    feedback_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    cur.execute(
        "INSERT INTO feedback (id, user_id, username, category, subject, message, created_at, is_resolved) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s, 0)",
        (feedback_id, user_id, username, category, subject, message, now)
    )
    conn.commit()
    cur.close()
    release_connection(conn)
    return {"id": feedback_id, "user_id": user_id, "username": username,
            "category": category, "subject": subject, "message": message,
            "created_at": now, "is_resolved": 0}


def get_all_feedback(app=None):
    """Return all feedback entries, newest first. Admin only."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute(
        "SELECT id, user_id, username, category, subject, message, created_at, is_resolved "
        "FROM feedback ORDER BY created_at DESC"
    )
    rows = cur.fetchall()
    cols = ['id', 'user_id', 'username', 'category', 'subject', 'message', 'created_at', 'is_resolved']
    results = [dict(zip(cols, r)) for r in rows]
    cur.close()
    release_connection(conn)
    return results


def mark_feedback_resolved(feedback_id, app=None):
    """Mark a feedback entry as resolved."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("UPDATE feedback SET is_resolved = 1 WHERE id = %s", (feedback_id,))
    conn.commit()
    cur.close()
    release_connection(conn)

