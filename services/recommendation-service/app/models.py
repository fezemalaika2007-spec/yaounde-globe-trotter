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
    """Get a PostgreSQL connection from connection pool or create fallback."""
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
    """Create the destinations and ratings tables and seed initial data if empty."""
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

    # Ensure the fsq_id column exists (safe migration for existing DBs).
    cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name='destinations'")
    existing_cols = {r[0] for r in cur.fetchall()}
    if "fsq_id" not in existing_cols:
        cur.execute("ALTER TABLE destinations ADD COLUMN fsq_id TEXT")

    conn.commit()
    cur.close()
    release_connection(conn)

    # Seed initial places if empty
    seed_initial_destinations(app)



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
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("SELECT * FROM destinations ORDER BY name ASC")
    rows = cur.fetchall()
    results = [_row_to_dict(r, cur) for r in rows]
    cur.close()
    release_connection(conn)
    return results


def get_destination_by_id(dest_id, app=None):
    """Return a single destination by its primary key."""
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("SELECT * FROM destinations WHERE id = %s", (dest_id,))
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


INITIAL_SEED_DESTINATIONS = [
    {
        "fsq_id": "seed-mont-febe",
        "name": "Mont Fébé",
        "area": "Yaoundé",
        "tags": json.dumps(["nature", "outdoors", "views", "history"]),
        "description": "Lush mountain peak offering panoramic views of Yaoundé city skyline.",
        "long_description": "Mont Fébé stands at 1,073 meters above sea level and provides breathtaking panoramic views of the entire city of Yaoundé. Home to the iconic Mont Fébé Hotel and a serene golf course, it is a favored resort for both locals and international travelers looking for fresh air, nature walks, and scenic sunrises.",
        "cost": 0.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/e/e9/Vue_sur_Yaound%C3%A9_depuis_le_mont_F%C3%A9b%C3%A9_en_octobre_1972.jpg",
        "latitude": 3.9056,
        "longitude": 11.5167,
        "address": "Mont Fébé, Yaoundé, Cameroon",
        "category": "Nature & Parks",
        "activities": json.dumps(["Hiking", "Sightseeing", "Photography", "Golf"]),
        "opening_hours": "Open 24/7",
        "star_rating": 4.8,
        "average_rating": 4.8,
        "rating_count": 12,
    },
    {
        "fsq_id": "seed-musee-national",
        "name": "Musée National du Cameroun",
        "area": "Centre-Ville, Yaoundé",
        "tags": json.dumps(["culture", "history", "museum", "city"]),
        "description": "The historic national museum housing artifacts from Cameroon's 250+ ethnic groups.",
        "long_description": "Housed in the former French governor's palace built in the 1930s, the Musée National du Cameroun displays rich cultural heritage, royal artifacts, traditional instruments, masks, and historical statues representing the 250+ ethnic groups of Cameroon.",
        "cost": 2000.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/a/a1/Mus%C3%A9e_National_du_Cameroun_01.JPG",
        "latitude": 3.8647,
        "longitude": 11.5186,
        "address": "Place de l'Indépendance, Yaoundé, Cameroon",
        "category": "Culture & History",
        "activities": json.dumps(["Museum Tour", "Cultural History", "Guided Walk"]),
        "opening_hours": "Tue-Sun 09:00 - 16:00",
        "star_rating": 4.6,
        "average_rating": 4.6,
        "rating_count": 8,
    },
    {
        "fsq_id": "seed-mvog-betsi-zoo",
        "name": "Parc Zoo-botanique de Mvog-Betsi",
        "area": "Mvog-Betsi, Yaoundé",
        "tags": json.dumps(["nature", "wildlife", "outdoors", "adventure"]),
        "description": "Botanical zoo and primate rescue sanctuary located right inside Yaoundé.",
        "long_description": "A green sanctuary in the heart of Mvog-Betsi managed in cooperation with primate protection initiatives. It features native trees, primates (mandrills, chimpanzees, baboons), reptiles, and exotic birds.",
        "cost": 1500.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/7/72/Parc_Zoo-Botanique_de_Mvog-Betsi.jpg",
        "latitude": 3.8431,
        "longitude": 11.4886,
        "address": "Quartier Mvog-Betsi, Yaoundé, Cameroon",
        "category": "Nature & Parks",
        "activities": json.dumps(["Zoo Tour", "Botany Walk", "Family Outing"]),
        "opening_hours": "Daily 08:00 - 18:00",
        "star_rating": 4.5,
        "average_rating": 4.5,
        "rating_count": 15,
    },
    {
        "fsq_id": "seed-cathedrale-yaounde",
        "name": "Cathédrale Notre-Dame-des-Victoires",
        "area": "Centre-Ville, Yaoundé",
        "tags": json.dumps(["culture", "architecture", "history"]),
        "description": "Architecturally striking Catholic cathedral built in 1952 in downtown Yaoundé.",
        "long_description": "Located at the central roundabout of Yaoundé, this cathedral boasts impressive modern mid-century architecture with giant triangular roof pillars and gorgeous interior stained glass.",
        "cost": 0.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/3/30/Cath%C3%A9drale_Notre-Dame_des_Victoires_Yaound%C3%A9_Cameroun.jpg",
        "latitude": 3.8661,
        "longitude": 11.5211,
        "address": "Place Cathédrale, Yaoundé, Cameroon",
        "category": "Culture & History",
        "activities": json.dumps(["Architecture", "Prayer", "Photography"]),
        "opening_hours": "Daily 07:00 - 19:00",
        "star_rating": 4.7,
        "average_rating": 4.7,
        "rating_count": 9,
    },
    {
        "fsq_id": "seed-reunification-monument",
        "name": "Monument de la Réunification",
        "area": "Ngoa-Ekellé, Yaoundé",
        "tags": json.dumps(["history", "culture", "monument"]),
        "description": "Iconic spiral monument celebrating the 1961 union of Anglophone and Francophone Cameroon.",
        "long_description": "Erected in the 1970s by sculptor Gédéon Mpando, this monument consists of a magnificent main spiral tower representing the merging of two rivers, accompanied by a statue of a father carrying children with torches.",
        "cost": 0.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/4/48/Monument_Reunification_4.JPG",
        "latitude": 3.8561,
        "longitude": 11.5119,
        "address": "Ngoa-Ekellé, Near University of Yaoundé I, Cameroon",
        "category": "Culture & History",
        "activities": json.dumps(["Sightseeing", "Historical Tour", "Photography"]),
        "opening_hours": "Open 24/7",
        "star_rating": 4.6,
        "average_rating": 4.6,
        "rating_count": 10,
    },
    {
        "fsq_id": "seed-bois-sainte-anastasie",
        "name": "Bois Sainte Anastasie",
        "area": "Warda, Yaoundé",
        "tags": json.dumps(["nature", "romantic", "outdoors", "food"]),
        "description": "Peaceful park and garden along the river, perfect for relaxing lunches and events.",
        "long_description": "Shaded by majestic palm trees and tropical flowers, Bois Sainte Anastasie offers quiet wooden bridges, outdoor dining, fresh fruit juices, and serene garden paths in central Yaoundé.",
        "cost": 1000.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/e/e7/Bois_Sainte_Anastasie%2C_Yaound%C3%A9%2C_Cameroun.jpg",
        "latitude": 3.8615,
        "longitude": 11.5152,
        "address": "Carrefour Warda, Yaoundé, Cameroon",
        "category": "Nature & Parks",
        "activities": json.dumps(["Relaxation", "Garden Walk", "Dining"]),
        "opening_hours": "Daily 09:00 - 20:00",
        "star_rating": 4.4,
        "average_rating": 4.4,
        "rating_count": 7,
    },
    {
        "fsq_id": "seed-marche-central",
        "name": "Marché Central de Yaoundé",
        "area": "Centre-Ville, Yaoundé",
        "tags": json.dumps(["shopping", "food", "culture", "city"]),
        "description": "Bustling central market full of local spices, fabrics, fresh fruits, and crafts.",
        "long_description": "The economic beating heart of Yaoundé. Explore hundreds of colorful stalls featuring authentic West African spices, traditional Toghu fabrics, tropical fruits, seafood, handcrafted wood carvings, and local street delicacies.",
        "cost": 0.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/d/da/March%C3%A9_central_-_Central_market_%28interior%29_in_Yaound%C3%A9.JPG",
        "latitude": 3.8640,
        "longitude": 11.5175,
        "address": "Avenue Kennedy, Yaoundé, Cameroon",
        "category": "Shopping",
        "activities": json.dumps(["Shopping", "Local Food", "Cultural Exploration"]),
        "opening_hours": "Mon-Sat 07:00 - 18:00",
        "star_rating": 4.3,
        "average_rating": 4.3,
        "rating_count": 14,
    },
    {
        "fsq_id": "seed-basilique-mvolye",
        "name": "Basilique Marie-Reine-des-Apôtres de Mvolyé",
        "area": "Mvolyé, Yaoundé",
        "tags": json.dumps(["culture", "architecture", "history", "religion"]),
        "description": "Minor basilica constructed on Mvolyé hill featuring magnificent stained glass windows and local granite.",
        "long_description": "Built on the hill of Mvolyé where the first Catholic missionaries settled in 1901. Consecrated as a Minor Basilica, it features a towering Marian roof structure, solid granite pillars, and extraordinary stained-glass artwork by local master artisans.",
        "cost": 0.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/e/e4/Mvolye1.jpg",
        "latitude": 3.8436,
        "longitude": 11.5050,
        "address": "Colline de Mvolyé, Yaoundé, Cameroon",
        "category": "Culture & History",
        "activities": json.dumps(["Architecture", "Cultural History", "Prayer"]),
        "opening_hours": "Daily 06:30 - 18:30",
        "star_rating": 4.8,
        "average_rating": 4.8,
        "rating_count": 11,
    },
    {
        "fsq_id": "seed-palais-sports-warda",
        "name": "Palais des Sports de Yaoundé (Warda)",
        "area": "Warda, Yaoundé",
        "tags": json.dumps(["sports", "architecture", "city", "events"]),
        "description": "Modern multi-purpose indoor sports complex and architectural icon located at Warda roundabout.",
        "long_description": "The Palais des Sports is Yaoundé's landmark indoor arena, seating over 5,000 spectators for international basketball, volleyball, boxing tournaments, cultural concerts, and national exhibitions.",
        "cost": 500.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/7/79/Yaound%C3%A9_Sports_Palace_2014_%2801%29.JPG",
        "latitude": 3.8681,
        "longitude": 11.5144,
        "address": "Carrefour Warda, Yaoundé, Cameroon",
        "category": "Sports & Events",
        "activities": json.dumps(["Sports Matches", "Concerts", "Architecture"]),
        "opening_hours": "Mon-Sat 08:00 - 20:00",
        "star_rating": 4.6,
        "average_rating": 4.6,
        "rating_count": 9,
    },
    {
        "fsq_id": "seed-hilton-hotel-yaounde",
        "name": "Hilton Hotel Yaoundé",
        "area": "Centre-Ville, Yaoundé",
        "tags": json.dumps(["accommodation", "luxury", "dining", "city"]),
        "description": "Premier international 5-star luxury hotel in central Yaoundé.",
        "long_description": "Located in the business center of Yaoundé, the 5-star Hilton Hotel offers panoramic city views, international restaurants, outdoor swimming pools, tennis courts, and executive suites.",
        "cost": 120000.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/f/f6/Hilton_Hotel_Yaound%C3%A9.JPG",
        "latitude": 3.8633,
        "longitude": 11.5190,
        "address": "Boulevard du 20 Mai, Yaoundé, Cameroon",
        "category": "Accommodation",
        "activities": json.dumps(["Fine Dining", "Luxury Stay", "Swimming"]),
        "opening_hours": "Open 24/7",
        "star_rating": 4.7,
        "average_rating": 4.7,
        "rating_count": 18,
    },
    {
        "fsq_id": "seed-palais-unite",
        "name": "Palais de l'Unité (Presidential Palace)",
        "area": "Etoundi, Yaoundé",
        "tags": json.dumps(["architecture", "landmark", "city", "history"]),
        "description": "The official residence and principal office of the President of Cameroon in Etoundi.",
        "long_description": "Situated on Etoundi hill in northern Yaoundé, the Palais de l'Unité is an architectural landmark surrounded by landscaped gardens, fountains, and impressive ceremonial gates.",
        "cost": 0.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/c/c3/Palais_pr%C3%A9sidentiel_du_Cameroun.jpg",
        "latitude": 3.9008,
        "longitude": 11.5233,
        "address": "Quartier Etoundi, Yaoundé, Cameroon",
        "category": "Culture & History",
        "activities": json.dumps(["Sightseeing", "Architecture", "Photography"]),
        "opening_hours": "Viewable from exterior",
        "star_rating": 4.5,
        "average_rating": 4.5,
        "rating_count": 6,
    },
    {
        "fsq_id": "seed-place-independance",
        "name": "Place de l'Indépendance",
        "area": "Centre-Ville, Yaoundé",
        "tags": json.dumps(["history", "monument", "city", "plaza"]),
        "description": "Historic public square and monument celebrating Cameroon's independence.",
        "long_description": "Central public square surrounded by historical government buildings and banks. The monument marks the historic site of national independence celebrations.",
        "cost": 0.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/4/48/Monument_place_de_l%27ind%C3%A9pendance_Yaound%C3%A9.jpg",
        "latitude": 3.8652,
        "longitude": 11.5181,
        "address": "Place de l'Indépendance, Yaoundé, Cameroon",
        "category": "Culture & History",
        "activities": json.dumps(["City Walk", "Historical Tour", "Photography"]),
        "opening_hours": "Open 24/7",
        "star_rating": 4.4,
        "average_rating": 4.4,
        "rating_count": 8,
    },
    {
        "fsq_id": "seed-mefou-sanctuary",
        "name": "Parc National de la Méfou",
        "area": "Mfou (near Yaoundé)",
        "tags": json.dumps(["nature", "wildlife", "outdoors", "adventure"]),
        "description": "Renowned primate sanctuary and national park protection area 45 mins from Yaoundé.",
        "long_description": "Covering over 1,000 hectares of lush tropical rainforest, Méfou National Park serves as a rescue sanctuary for western lowland gorillas, chimpanzees, and mandrills. Guided eco-tours take visitors along forest trails to observe protected primate troops in natural enclosures.",
        "cost": 5000.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/1/13/Case_d%27accueil_des_visiteurs%2C_Parc_des_Primates_de_la_Mefou%2C_Mefou%2C_R%C3%A9gion_du_Centre%2C_Cameroun.jpg",
        "latitude": 3.6125,
        "longitude": 11.5833,
        "address": "Route de Mfou, Region du Centre, Cameroon",
        "category": "Nature & Parks",
        "activities": json.dumps(["Primate Sanctuary Tour", "Rainforest Trekking", "Wildlife Photography"]),
        "opening_hours": "Daily 09:00 - 17:00",
        "star_rating": 4.9,
        "average_rating": 4.9,
        "rating_count": 22,
    },
    {
        "fsq_id": "seed-stade-ahidjo",
        "name": "Stade Ahmadou Ahidjo",
        "area": "Mfandena, Yaoundé",
        "tags": json.dumps(["sports", "stadium", "events", "city"]),
        "description": "Historic national sports stadium home of the Indomitable Lions football team.",
        "long_description": "Built in 1972 and modernized for the Africa Cup of Nations, this 40,000-capacity stadium hosts national team football matches, athletics competitions, and grand public events in Yaoundé.",
        "cost": 1000.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/2/21/Soccer_Training_in_the_Yaound%C3%A9_town.jpg",
        "latitude": 3.8825,
        "longitude": 11.5361,
        "address": "Quartier Mfandena, Yaoundé, Cameroon",
        "category": "Sports & Events",
        "activities": json.dumps(["Football Matches", "Athletics", "Stadium Tour"]),
        "opening_hours": "Event-based",
        "star_rating": 4.6,
        "average_rating": 4.6,
        "rating_count": 14,
    },
    {
        "fsq_id": "seed-marche-djoungolo",
        "name": "Marché Artisanal de Djoungolo",
        "area": "Djoungolo, Yaoundé",
        "tags": json.dumps(["shopping", "crafts", "culture", "art"]),
        "description": "Traditional craft market specializing in carved wooden masks, bronze statues, and Toghu wear.",
        "long_description": "A hub for local artists and craftsmen displaying hand-woven baskets, traditional masks, bronze sculptures, beaded jewelry, and tailored Cameroonian garments.",
        "cost": 0.0,
        "image": "https://upload.wikimedia.org/wikipedia/commons/5/57/Street_next_to_Central_Market_Yaound%C3%A9_2014.JPG",
        "latitude": 3.8689,
        "longitude": 11.5225,
        "address": "Djoungolo, Yaoundé, Cameroon",
        "category": "Shopping",
        "activities": json.dumps(["Craft Shopping", "Art Appreciation", "Cultural Gift Buying"]),
        "opening_hours": "Mon-Sat 08:00 - 18:00",
        "star_rating": 4.5,
        "average_rating": 4.5,
        "rating_count": 10,
    }
]


def seed_initial_destinations(app=None):
    """Upsert default authentic Yaoundé destinations and clean generic URLs."""
    conn = get_connection(app)
    cur = conn.cursor()
    try:
        # Purge old generic unsplash images if present from legacy runs
        cur.execute("DELETE FROM destinations WHERE image LIKE '%unsplash.com%' OR image = '' OR image IS NULL")
        conn.commit()

        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        for d in INITIAL_SEED_DESTINATIONS:
            cur.execute("SELECT id FROM destinations WHERE fsq_id = %s", (d["fsq_id"],))
            row = cur.fetchone()
            if row:
                cur.execute("""
                    UPDATE destinations SET
                        name = %s, area = %s, tags = %s, description = %s,
                        long_description = %s, cost = %s, image = %s,
                        latitude = %s, longitude = %s, address = %s,
                        category = %s, activities = %s, opening_hours = %s,
                        star_rating = %s, average_rating = %s, rating_count = %s,
                        image_source = 'wikimedia', last_synced_at = %s
                    WHERE fsq_id = %s
                """, (
                    d["name"], d["area"], d["tags"], d["description"],
                    d["long_description"], d["cost"], d["image"],
                    d["latitude"], d["longitude"], d["address"],
                    d["category"], d["activities"], d["opening_hours"],
                    d["star_rating"], d["average_rating"], d["rating_count"],
                    now, d["fsq_id"]
                ))
            else:
                dest_id = str(uuid.uuid4())
                cur.execute("""
                    INSERT INTO destinations (
                        id, fsq_id, name, area, tags, description, long_description,
                        cost, image, image_source, latitude, longitude, address,
                        category, activities, opening_hours, average_rating,
                        rating_count, star_rating, last_synced_at
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'wikimedia', %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    dest_id, d["fsq_id"], d["name"], d["area"], d["tags"], d["description"],
                    d["long_description"], d["cost"], d["image"], d["latitude"],
                    d["longitude"], d["address"], d["category"], d["activities"],
                    d["opening_hours"], d["average_rating"], d["rating_count"],
                    d["star_rating"], now
                ))
        conn.commit()
    except Exception as e:
        print(f"Error seeding initial destinations: {e}")
    finally:
        cur.close()
        release_connection(conn)

