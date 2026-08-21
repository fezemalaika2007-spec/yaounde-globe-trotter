import os
import sys
import json
import uuid
import datetime

_root_dir = os.path.abspath(os.path.dirname(__file__))
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)

from dotenv import load_dotenv
load_dotenv(os.path.join(_root_dir, "..", ".env"))

from app.models import get_connection, release_connection

def insert_google_maps_destination():
    dest_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    name = "I Love My Country Cameroon Round About"
    area = "Warda, Yaoundé"
    address = "Carrefour Warda, Yaoundé, Cameroon"
    category = "Top Attractions"
    description = "Famous civic roundabout landmark in Yaoundé featuring the vibrant I Love My Country Cameroon patriotic sign and monument."
    long_description = "Located in the central Warda district of Yaoundé, the I Love My Country Cameroon Round About is an iconic public landmark and tourist attraction. Featuring vibrant patriotic signage and artistic installations, it is a favored spot for city walks, photo opportunities, and cultural pride."
    
    image1 = "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWn8hS7T1ZNlGLbk3XbjnKbd3zjVRiVPTyN8-YcxbKdXTLgN8rMUN-CoytwYCurjM4MGStnee4TJ6NMcrcn3UY1iu-D6nc5eJVRtGZW-icvKeH_i5Abd-IHp_j8ExqMItsnApx8hdQ=w450-h160-p-k-no"
    image2 = "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWmRKnhgvMnnqObAlYBrnT8DiLeUfv6vjrE0O-ccHRIgKk6aA9153Kh8fB-GmcOUiTnxWI7WgQCGRMXQiAFOMxIOSEVIqkjpWUFgL2HoyGesUZuZ2EuY24MCFJowdwX3b3tZEYzJ=w450-h160-p-k-no"
    website = "https://www.google.com/maps/place/I+Love+My+Country+Cameroon+Round+About/@3.8661674,11.3834641,12z"
    
    tags = json.dumps(["landmark", "attraction", "culture", "photography", "yaounde"])
    activities = json.dumps(["Photography", "City Walk", "Sightseeing"])
    images = json.dumps([image1, image2])

    conn = get_connection()
    cur = conn.cursor()
    
    # Ensure destinations table exists
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
        INSERT INTO destinations (
            id, fsq_id, name, area, tags, description, long_description,
            cost, image, image_source, latitude, longitude, address,
            category, activities, opening_hours, website, average_rating,
            rating_count, star_rating, images, last_synced_at
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s
        )
    """, (
        dest_id, 'gmap-ilovecameroon', name, area, tags, description, long_description,
        0.0, image1, 'google_maps', 3.8661674, 11.5153, address,
        category, activities, 'Open 24/7', website, 4.8,
        5, 4.8, images, now
    ))

    conn.commit()
    print("SUCCESS: Inserted destination ID:", dest_id)
    cur.close()
    release_connection(conn)

if __name__ == "__main__":
    insert_google_maps_destination()
