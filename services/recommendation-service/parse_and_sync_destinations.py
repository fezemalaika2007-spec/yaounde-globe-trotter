import os
import sys
import json
import uuid
import datetime
import urllib.parse
import subprocess

_root_dir = os.path.abspath(os.path.dirname(__file__))
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)

from app.models import get_connection, release_connection, clear_all_destinations, init_db

DEST_META_DATABASE = {
    "mont fébé": {
        "category": "Top Attractions",
        "desc": "Panoramic hilltop scenic lookout rising 1,070 meters above sea level, offering cool mountain breeze, views over all seven hills of Yaoundé, and the Benedictine museum.",
        "activities": ["Panoramic Viewing", "Mountain Sightseeing", "Benedictine Museum Tour"],
        "rating": 4.9, "count": 45,
        "gmaps": "https://www.google.com/maps/search/Mont+Febe+Yaounde"
    },
    "national museum": {
        "category": "Culture & History",
        "desc": "Housed in the former Governor's Palace, exhibiting royal costumes, traditional instruments, sculptures, and historical relics of Cameroon's 250+ ethnic groups.",
        "activities": ["Museum Tour", "Cultural History", "Guided Viewing"],
        "rating": 4.8, "count": 34,
        "gmaps": "https://www.google.com/maps/place/National+Museum/@3.8616357,11.5167199,17z/data=!3m1!4b1!4m6!3m5!1s0x108bcf84f791d633:0x56164fae3b22eac4!8m2!3d3.8616357!4d11.5167199!16s%2Fg%2F12z65blr2?entry=ttu&g_ep=EgoyMDI2MDgxOS4wIKXMDSoASAFQAw%3D%3D"

    },
    "reunification monument": {
        "category": "Culture & History",
        "desc": "Monumental twin spiral sculpture constructed in 1973 symbolizing the historic 1961 unification of British Southern Cameroons and French Cameroun.",
        "activities": ["Historical Tour", "Architecture", "Photography"],
        "rating": 4.7, "count": 22,
        "gmaps": "https://www.google.com/maps/search/Reunification+Monument+Yaounde"
    },
    "bois sainte anastasie": {
        "category": "Nature & Parks",
        "desc": "Tranquil tropical urban park with paved shaded pathways, wooden bridges over streams, lush flowerbeds, and outdoor cafe dining.",
        "activities": ["Nature Walk", "Relaxation", "Picnic", "Garden Dining"],
        "rating": 4.7, "count": 19,
        "gmaps": "https://www.google.com/maps/search/Bois+Sainte+Anastasie+Yaounde"
    },
    "cathedral": {
        "category": "Culture & History",
        "desc": "Striking modern triangular cathedral consecrated in 1955, featuring impressive stained glass windows and seating for over 5,000 worshippers.",
        "activities": ["Architecture Viewing", "Spiritual Visit", "Photography"],
        "rating": 4.8, "count": 30,
        "gmaps": "https://www.google.com/maps/search/Cathedrale+Notre+Dame+des+Victoires+Yaounde"
    },
    "mvog-betsi zoo": {
        "category": "Nature & Parks",
        "desc": "Well-maintained wildlife sanctuary and primate rescue center housing drill monkeys, baboons, native birds, reptiles, and tropical flora.",
        "activities": ["Wildlife Viewing", "Guided Zoo Tour", "Family Walk"],
        "rating": 4.6, "count": 25,
        "gmaps": "https://www.google.com/maps/search/Mvog-Betsi+Zoo+Yaounde"
    },
    "craft market": {
        "category": "Shopping",
        "desc": "Vibrant artisan market display featuring handcrafted wood carvings, bronze statues, traditional Bamileke masks, beadwork, and local fabrics.",
        "activities": ["Handicraft Shopping", "Souvenir Browsing", "Cultural Crafts"],
        "rating": 4.5, "count": 17,
        "gmaps": "https://www.google.com/maps/search/Centre+Artisanal+de+Yaounde"
    },
    "palais polyvalent": {
        "category": "Top Attractions",
        "desc": "Modern multi-purpose indoor sports arena and cultural complex hosting international sporting matches, concerts, and national expos.",
        "activities": ["Sports Events", "Concerts", "City Landmark Tour"],
        "rating": 4.6, "count": 15,
        "gmaps": "https://www.google.com/maps/search/Palais+des+Sports+Yaounde"
    },
    "basilique": {
        "category": "Culture & History",
        "desc": "Masterpiece Marian minor basilica constructed on the historical site of Cameroon's first Catholic mission, famous for its grand architectural roof and stained glass.",
        "activities": ["Architecture", "Heritage Tour", "Photography"],
        "rating": 4.8, "count": 20,
        "gmaps": "https://www.google.com/maps/search/Basilique+Marie+Reine+des+Apotres+Mvolye"
    },
    "ebogo": {
        "category": "Adventure",
        "desc": "Serene tropical ecotourism reserve offering traditional dugout canoe trips along the quiet Nyong River, century-old Entandrophragma trees, and jungle nature trails.",
        "activities": ["Canoeing", "Jungle Hiking", "Ecotourism", "Bird Watching"],
        "rating": 4.7, "count": 14,
        "gmaps": "https://www.google.com/maps/search/Ebogo+Ecotourism+Yaounde/@3.5823257,11.471691,11z/data=!3m1!4b1?entry=ttu&g_ep=EgoyMDI2MDgxOS4wIKXMDSoASAFQAw%3D%3D"
    },
    "i love my country": {
        "category": "Culture & History",
        "desc": "Iconic civic monument landmark featuring a decorative patriotic sign, national colors, and night lighting located at central Carrefour Warda.",
        "activities": ["Photography", "Civic Walk", "Sightseeing"],
        "rating": 4.9, "count": 28,
        "gmaps": "https://www.google.com/maps/place/I+Love+My+Country+Cameroon+Round+About/@3.8661674,11.3834641,12z"
    }
}



def parse_txt_and_sync():
    dest_txt_path = os.path.join(_root_dir, "..", "..", "destinations.txt")
    if not os.path.exists(dest_txt_path):
        print(f"ERROR: File not found at {dest_txt_path}")
        return

    with open(dest_txt_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    entries = []
    current_label = ""

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            if "http://" in stripped or "https://" in stripped:
                continue
            if ":" in stripped:
                current_label = stripped.split(":", 1)[1].strip()
            else:
                clean_tag = stripped.replace("#", "").strip()
                current_label = clean_tag
        elif stripped.startswith("http://") or stripped.startswith("https://"):
            name = current_label if current_label else f"Destination {len(entries)+1}"
            entries.append((name, stripped))
            current_label = ""

    print(f"--- PARSED {len(entries)} DESTINATIONS FROM destinations.txt ---")
    for i, (name, url) in enumerate(entries):
        print(f"  {i+1}. {name}")

    # Initialize database tables if missing
    init_db()

    # Clear previous destinations for a clean sync
    clear_all_destinations()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    conn = get_connection()
    cur = conn.cursor()

    inserted = []
    for i, (name, raw_url) in enumerate(entries):
        name_lower = name.lower()
        meta = None
        for key, val in DEST_META_DATABASE.items():
            if key in name_lower:
                meta = val
                break
        
        if not meta:
            meta = {
                "category": "Top Attractions",
                "desc": f"Famous travel destination in Yaoundé, Cameroon: {name}.",
                "activities": ["Sightseeing", "Photography", "City Tour"],
                "rating": 4.5,
                "count": 10,
                "gmaps": raw_url if "google.com/maps" in raw_url else ("https://www.google.com/maps/search/" + urllib.parse.quote(name))
            }

        dest_image = raw_url
        dest_website = meta["gmaps"]
        if "google.com/maps" in raw_url:
            dest_website = raw_url
            dest_image = "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=800&q=80" if "express" in name_lower or "voyage" in name_lower else "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=800&q=80"

        dest_id = str(uuid.uuid4())
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
            dest_id,
            f"gmap-parsed-{i+1}",
            name,
            "Yaoundé, Cameroon",
            json.dumps(["yaounde", "cameroon", meta["category"].lower().replace(" ", "")]),
            meta["desc"],
            meta["desc"] + " Located in Yaoundé, Cameroon.",
            0.0,
            dest_image,
            "google_maps",
            3.8661674,
            11.5153,
            "Yaoundé, Cameroon",
            meta["category"],
            json.dumps(meta["activities"]),
            "Open daily",
            dest_website,
            meta["rating"],
            meta["count"],
            meta["rating"],
            json.dumps([dest_image]),
            now
        ))
        inserted.append((dest_id, name))

    conn.commit()
    cur.close()
    release_connection(conn)

    print(f"\nSUCCESS: Inserted {len(inserted)} destinations into local database.")

    # Automatically sync local destinations.db into docker container recommendation-service
    local_db_path = os.path.join(_root_dir, "destinations.db")
    if os.path.exists(local_db_path):
        try:
            cmd = ["docker", "cp", local_db_path, "recommendation-service:/recommendation-service/destinations.db"]
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0:
                print("SUCCESS: Synced database directly into Docker container (recommendation-service)!")
            else:
                print(f"Notice: Docker sync failed ({res.stderr.strip()}). Local database is updated.")
        except Exception as e:
            print(f"Notice: Docker copy skipped ({e}).")

if __name__ == "__main__":
    parse_txt_and_sync()
