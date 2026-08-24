import os
import sys
import json
import uuid
import datetime
import urllib.parse
import subprocess
import re

_root_dir = os.path.abspath(os.path.dirname(__file__))
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)

from app.models import get_connection, release_connection, clear_all_destinations, init_db

# Specific high-quality place photo mappings for known places
KNOWN_PLACE_PHOTOS = {
    "playce yaounde": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWnGJ8xQxKaLreAJm7fzvvweZHmPlMxuppI6Ti6FDqI6uSD6PBZ31f1dcZWKAMrGxu0dNqGZsVOESMJ1Vq4WK3c5XfooEp8p_A06qXQZ2kt-cbhCFAOErD883mngzjpVuSa-IY5UVux2HIs=w408-h307-k-no",
    "general express": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWloAOppif50O2ZNT5xuEUFuI1rCEaa5gk858TwLR_-BC7_q-ckRMwmIEtcxl0haMAWa3L-mCNx1kbw3Q59XPoiFlwnG9ScoVnBuIGNh7GIp6dO0yvUiMMt90xIqPbJCDgf-iNEthw=w408-h544-k-no",
    "fresh lunch": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWnYYEjx6GCK3k-GrbcWvHhnAVrfoGXGzH66LhBOcS-JfcuWYQO4Qqjeev-Vq6yoscPWVuqsgZWngOA7ifPtrgz1lpmj2x8ZMvG3haIy6Dgg56K4MIjA-JdT-3ieJZ8nBC3ZudHa=w504-h240-k-no",
   
}

def extract_name_from_url(url):
    """Extract human readable place name from Google Maps place URL."""
    try:
        if "/place/" in url:
            part = url.split("/place/")[1].split("/")[0]
            unquoted = urllib.parse.unquote(part).replace("+", " ").strip()
            if unquoted:
                return unquoted
    except Exception:
        pass
    return ""

def derive_metadata(name, url):
    """Derive category, description, and activities for any place name."""
    lower = name.lower()
    
    if any(k in lower for k in ["playce", "carrefour", "mall", "market", "marché", "shop", "centre artisanal"]):
        return {
            "category": "Shopping",
            "desc": f"Premier shopping center and retail destination in Yaoundé ({name}).",
            "activities": ["Shopping", "Dining", "Supermarket", "Retail"],
            "rating": 4.8,
            "count": 35,
            "gmaps": url
        }
    elif any(k in lower for k in ["express", "voyage", "bus", "station", "gare", "mvan"]):
        return {
            "category": "Top Attractions",
            "desc": f"Major intercity bus terminal and travel service hub in Yaoundé ({name}).",
            "activities": ["Travel", "Bus Terminal", "Transport Service"],
            "rating": 4.6,
            "count": 25,
            "gmaps": url
        }
    elif any(k in lower for k in ["park", "garden", "parc", "bois", "zoo", "nature"]):
        return {
            "category": "Nature & Parks",
            "desc": f"Scenic tropical park and natural relaxation spot in Yaoundé ({name}).",
            "activities": ["Nature Walk", "Relaxation", "Outdoor Recreation"],
            "rating": 4.7,
            "count": 20,
            "gmaps": url
        }
    elif any(k in lower for k in ["museum", "musée", "monument", "cathedral", "cathédrale", "basilique", "culture"]):
        return {
            "category": "Culture & History",
            "desc": f"Famous historical and cultural landmark in Yaoundé ({name}).",
            "activities": ["Sightseeing", "Cultural History", "Guided Tour"],
            "rating": 4.8,
            "count": 30,
            "gmaps": url
        }
    elif any(k in lower for k in ["river", "hiking", "ecotourism", "mountain", "mont", "chute"]):
        return {
            "category": "Adventure",
            "desc": f"Exciting outdoor adventure and ecotourism destination near Yaoundé ({name}).",
            "activities": ["Hiking", "Adventure", "Exploration"],
            "rating": 4.7,
            "count": 18,
            "gmaps": url
        }
    else:
        return {
            "category": "Top Attractions",
            "desc": f"Popular destination in Yaoundé, Cameroon: {name}.",
            "activities": ["Sightseeing", "Photography", "City Visit"],
            "rating": 4.5,
            "count": 12,
            "gmaps": url
        }

def get_exact_image_for_destination(name, raw_url):
    """Return exact direct image URL if provided, or mapped photo for Google Maps URLs."""
    # 1. Direct photo / googleusercontent image URL
    if raw_url.startswith("http") and ("googleusercontent.com" in raw_url or raw_url.endswith((".jpg", ".png", ".webp", ".jpeg"))):
        return raw_url

    # 2. Match known place names
    lower = name.lower()
    for key, photo_url in KNOWN_PLACE_PHOTOS.items():
        if key in lower:
            return photo_url

    # 3. Category-based realistic photos
    if any(k in lower for k in ["shop", "mall", "market", "playce"]):
        return "https://images.unsplash.com/photo-1555421689-491a97ff2040?auto=format&fit=crop&w=800&q=80"
    if any(k in lower for k in ["park", "garden", "zoo", "nature"]):
        return "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=800&q=80"
    if any(k in lower for k in ["museum", "culture", "monument", "cathedral"]):
        return "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=800&q=80"

    return "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=800&q=80"

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
                current_label = stripped.replace("#", "").strip()
        elif stripped.startswith("http://") or stripped.startswith("https://"):
            name = current_label
            if not name:
                name = extract_name_from_url(stripped)
            if not name:
                name = f"Destination {len(entries)+1}"
            entries.append((name, stripped))
            current_label = ""

    print(f"--- PARSED {len(entries)} DESTINATION(S) FROM destinations.txt ---")
    for i, (name, url) in enumerate(entries):
        print(f"  {i+1}. {name}")

    # Ensure database table exists
    init_db()

    # Clear previous database state for clean synchronization
    clear_all_destinations()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    conn = get_connection()
    cur = conn.cursor()

    inserted = []
    for i, (name, raw_url) in enumerate(entries):
        meta = derive_metadata(name, raw_url)
        dest_website = raw_url if "google.com/maps" in raw_url else meta["gmaps"]
        dest_image = get_exact_image_for_destination(name, raw_url)

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
            3.8743774,
            11.5123432,
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

    print(f"\nSUCCESS: Inserted {len(inserted)} destination(s) into local database.")

    # Automatically sync local destinations.db into docker container recommendation-service
    local_db_path = os.path.join(_root_dir, "destinations.db")
    if os.path.exists(local_db_path):
        try:
            cmd = ["docker", "cp", local_db_path, "recommendation-service:/recommendation-service/destinations.db"]
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0:
                print("SUCCESS: Synced database directly into Docker container (recommendation-service)!")
            else:
                print(f"Notice: Docker sync status ({res.stderr.strip()}). Local database updated.")
        except Exception as e:
            print(f"Notice: Docker sync skipped ({e}).")

if __name__ == "__main__":
    parse_txt_and_sync()
