import os
import sys
import json
import uuid
import datetime
import urllib.parse
import subprocess
import re
import unicodedata
import base64
import urllib.request
import logging

_root_dir = os.path.abspath(os.path.dirname(__file__))
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)

from app.models import get_connection, release_connection, clear_all_destinations, init_db

# Place photo mappings — add your lh3.googleusercontent.com image URLs here (all keys lowercase)
KNOWN_PLACE_PHOTOS = {
    "playce yaounde": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWnGJ8xQxKaLreAJm7fzvvweZHmPlMxuppI6Ti6FDqI6uSD6PBZ31f1dcZWKAMrGxu0dNqGZsVOESMJ1Vq4WK3c5XfooEp8p_A06qXQZ2kt-cbhCFAOErD883mngzjpVuSa-IY5UVux2HIs=w408-h307-k-no",
    "general express": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWloAOppif50O2ZNT5xuEUFuI1rCEaa5gk858TwLR_-BC7_q-ckRMwmIEtcxl0haMAWa3L-mCNx1kbw3Q59XPoiFlwnG9ScoVnBuIGNh7GIp6dO0yvUiMMt90xIqPbJCDgf-iNEthw=w408-h544-k-no",
    "fresh lunch": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWnYYEjx6GCK3k-GrbcWvHhnAVrfoGXGzH66LhBOcS-JfcuWYQO4Qqjeev-Vq6yoscPWVuqsgZWngOA7ifPtrgz1lpmj2x8ZMvG3haIy6Dgg56K4MIjA-JdT-3ieJZ8nBC3ZudHa=w504-h240-k-no",
    "hilton": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWlB9aMzHeHos3IFh4wtTmQq8v8vd6f06kCRkuXxsnlq-E_FO84UUpSZvz21eMLb2HJba1FdFp1jW-z1MZ9zw_F3JHRTLWfCMWc6BQj6fcuO6JuVZMdS0blMxTuKuKXuRE7FRGgyLQBeDhA=w408-h273-k-no",
    "le continent restaurant": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWmdRYaFw8-feoCxdg3AXQissR5eqLm6OXeBv1_nvAwZswwLUDDDNzIpOJzl__UvpaxChqCYlbz0CSnjQfjyWl8IZ-AWVTAae1a3qNk4zlVkX33BjCnb7N69DWe5LmsWeGygRPqy=w408-h306-k-no",
    "cosy pool": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWmDBuprrKdvGAlDOmncVbZ1MJXeLLqfVT7Phoe72yl8h10aixRoPKNe2G0jvyu4VXIEMljiz0hdWCqAkoL7qIUqItFi97kz5Eur_ARXROBnPuqqBYz5Tgp0MTwTkjs88j7lPqkX=w426-h240-k-no",
    "cosy pool yaounde": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWmDBuprrKdvGAlDOmncVbZ1MJXeLLqfVT7Phoe72yl8h10aixRoPKNe2G0jvyu4VXIEMljiz0hdWCqAkoL7qIUqItFi97kz5Eur_ARXROBnPuqqBYz5Tgp0MTwTkjs88j7lPqkX=w426-h240-k-no",
    "blackitude museum": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWmUjQUiJXbecmKC533fikxUjOFLaTvUnl7xXGrGWFAk76vqwAOzZZCBbPzJW1HIsVtOi40vWQmqFtsIfcJd82jniLoYpUhtKAB2zsM8QzUazFPOVwXbdZ8AYNfZgmgXPUpSPq8=w408-h272-k-no",
    "pharmacie nkozoa": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWnJ0nB1d-XkLiTRDWvUUYklzAqkAe559Zkalovc9QQrQA46fvoJfRQ8ZsDRmyAXtkqCI3i9uost1D-EwCooTFcSLiNuYioacByzbSo2HGZFfYHCOCi7JW3JdCbIoWFpFCJA1d_U=w408-h877-k-no",
    "place charles atangana": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWm5x81unNsApCwCxH8mJPr2QAV2je1SkPWrnaiKUZlsTOan_TzBXeLeMCmpcOkVxkjl7MnIFwFsMix8rD028wDwNqjDwz8WxzGxfUX_2TAF4Vbbhgy_TVlA0vVoQ1DsY8a0Euvz=w408-h272-k-no",
    "monument jaime mon pays": "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWlSzhjDxJyNUYv2f8cdfr23F5PJ_DF-sCv_N84t7kfEQsmshSLcpUKjls78lBtXwxWXcFJMUSepwXKES58Nw6PQLLvZvqChD8-7_WFsL6NUvPItN4fD0SiOhpOnV15cKCNXQtbs=w408-h306-k-no",
}

# Default placeholder when no image is provided
DEFAULT_PLACEHOLDER = "https://via.placeholder.com/800x600.png?text=No+Image"

def normalize_text(text):
    """Normalize text by stripping accents, punctuation, and lowering case."""
    if not text:
        return ""
    nfkd = unicodedata.normalize('NFKD', str(text))
    ascii_text = ''.join(c for c in nfkd if not unicodedata.combining(c))
    clean = re.sub(r'[^a-zA-Z0-9\s]', ' ', ascii_text).lower()
    return re.sub(r'\s+', ' ', clean).strip()

def match_known_photo(name, raw_url=""):
    """Match destination name or URL slug against KNOWN_PLACE_PHOTOS."""
    norm_name = normalize_text(name)
    url_slug = ""
    if raw_url and "/place/" in raw_url:
        try:
            part = raw_url.split("/place/")[1].split("/")[0]
            url_slug = normalize_text(urllib.parse.unquote(part))
        except Exception:
            pass

    for key, photo_url in KNOWN_PLACE_PHOTOS.items():
        norm_key = normalize_text(key)
        if not norm_key:
            continue
        # Exact or substring match on name
        if norm_key in norm_name or norm_name in norm_key:
            return photo_url
        # Match on URL slug
        if url_slug and (norm_key in url_slug or url_slug in norm_key):
            return photo_url
        # Token intersection match
        key_tokens = [t for t in norm_key.split() if len(t) > 2]
        name_tokens = set(norm_name.split() + url_slug.split())
        if key_tokens and all(kt in name_tokens for kt in key_tokens):
            return photo_url

    return None

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

def extract_coordinates_from_url(url):
    """Extract (lat, lng) from Google Maps URL if available."""
    try:
        pin_match = re.search(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)', url)
        if pin_match:
            return float(pin_match.group(1)), float(pin_match.group(2))
        view_match = re.search(r'@(-?\d+\.\d+),(-?\d+\.\d+)', url)
        if view_match:
            return float(view_match.group(1)), float(view_match.group(2))
    except Exception:
        pass
    return 3.8743774, 11.5123432  # Default Yaoundé center

def is_direct_image_url(url):
    """Check if URL points directly to an image or image CDN, or local asset."""
    if not url:
        return False
    clean = url.strip()
    if clean.startswith("assets/") or clean.startswith("assets\\") or "/assets/" in clean:
        return True
    if not clean.startswith("http"):
        return False
    lower = clean.lower()
    if "googleusercontent.com" in lower or "ggpht.com" in lower or "wikimedia.org" in lower:
        return True
    if any(lower.endswith(ext) for ext in [".jpg", ".jpeg", ".png", ".webp", ".gif", ".svg", ".avif"]):
        return True
    return False

def derive_metadata(name, url=""):
    """Derive category, description, and activities for any place name."""
    norm = normalize_text(name)

    if any(k in norm for k in ["hotel", "hilton", "radisson", "djemeni", "mont febe", "la falaise", "resort", "lodge", "auberge", "inn"]):
        return {
            "category": "Hotels & Accommodation",
            "desc": f"Premier luxury hotel and accommodation destination in Yaoundé ({name}).",
            "activities": ["Accommodation", "Luxury Stay", "Dining", "Swimming Pool", "Relaxation"],
            "rating": 4.8, "count": 45, "gmaps": url
        }
    elif any(k in norm for k in ["restaurant", "lunch", "cafe", "bistro", "bakery", "patisserie", "food", "lounge", "grill", "snack", "traiteur"]):
        return {
            "category": "Food & Dining",
            "desc": f"Popular dining and gastronomic spot in Yaoundé ({name}).",
            "activities": ["Dining", "Local Cuisine", "Drinks", "Gastronomy"],
            "rating": 4.7, "count": 35, "gmaps": url
        }
    elif any(k in norm for k in ["playce", "carrefour", "mall", "market", "marche", "shop", "supermarche", "supermarket", "centre artisanal", "mokolo"]):
        return {
            "category": "Shopping",
            "desc": f"Premier shopping center and retail destination in Yaoundé ({name}).",
            "activities": ["Shopping", "Dining", "Supermarket", "Retail"],
            "rating": 4.8, "count": 35, "gmaps": url
        }
    elif any(k in norm for k in ["express", "voyage", "bus", "station", "gare", "mvan", "aeroport", "airport", "taxi", "agence"]):
        return {
            "category": "Travel & Transport",
            "desc": f"Major intercity travel and transport service hub in Yaoundé ({name}).",
            "activities": ["Intercity Travel", "Bus Terminal", "Transport Service"],
            "rating": 4.6, "count": 30, "gmaps": url
        }
    elif any(k in norm for k in ["park", "garden", "parc", "bois", "zoo", "nature", "mefou", "sainte anastasie", "botanique"]):
        return {
            "category": "Nature & Parks",
            "desc": f"Scenic tropical park and natural relaxation spot in Yaoundé ({name}).",
            "activities": ["Nature Walk", "Relaxation", "Outdoor Recreation", "Wildlife"],
            "rating": 4.8, "count": 30, "gmaps": url
        }
    elif any(k in norm for k in ["museum", "musee", "monument", "cathedral", "cathedrale", "basilique", "culture", "reunification", "national", "palais"]):
        return {
            "category": "Culture & History",
            "desc": f"Famous historical and cultural landmark in Yaoundé ({name}).",
            "activities": ["Sightseeing", "Cultural History", "Guided Tour", "Architecture"],
            "rating": 4.8, "count": 30, "gmaps": url
        }
    elif any(k in norm for k in ["river", "hiking", "ecotourism", "mountain", "mont", "chute", "cascade", "ebogo", "akok"]):
        return {
            "category": "Adventure",
            "desc": f"Exciting outdoor adventure and ecotourism destination near Yaoundé ({name}).",
            "activities": ["Hiking", "Adventure", "Exploration", "Sightseeing"],
            "rating": 4.7, "count": 20, "gmaps": url
        }
    else:
        return {
            "category": "Top Attractions",
            "desc": f"Popular destination in Yaoundé, Cameroon: {name}.",
            "activities": ["Sightseeing", "Photography", "City Visit"],
            "rating": 4.5, "count": 15, "gmaps": url
        }

def get_exact_image_for_destination(name, raw_url="", explicit_image=None):
    """Return exact image URL. No random/Unsplash fallbacks — only real photos."""
    # 1. Explicitly supplied image in destinations.txt
    if explicit_image and is_direct_image_url(explicit_image):
        return explicit_image

    # 2. Match from known place photos dictionary
    matched = match_known_photo(name, raw_url)
    if matched:
        return matched

    # 3. Direct photo / image URL passed as raw_url
    if is_direct_image_url(raw_url):
        return raw_url

    # 4. No image found — return placeholder
    return DEFAULT_PLACEHOLDER

def parse_destinations_file(dest_txt_path):
    """Parse destinations.txt supporting flexible formats."""
    with open(dest_txt_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    entries = []
    current_entry = None

    for line in lines:
        raw_line = line.strip()
        if not raw_line:
            continue

        if "parse_and_sync_destinations.py" in raw_line:
            continue

        if raw_line.startswith("#"):
            clean_head = raw_line.lstrip("#").strip()
            if not clean_head:
                continue

            if current_entry and (current_entry.get("url") or current_entry.get("image")):
                entries.append(current_entry)
                current_entry = None

            dest_name = ""
            dest_image = ""

            if "|" in clean_head:
                parts = clean_head.split("|", 1)
                clean_head = parts[0].strip()
                extra = parts[1].strip()
                if is_direct_image_url(extra) or extra.startswith("http") or extra.startswith("assets"):
                    dest_image = extra

            if ":" in clean_head:
                name_part = clean_head.split(":", 1)[1].strip()
                if name_part:
                    dest_name = name_part
            else:
                dest_name = clean_head

            current_entry = {
                "name": dest_name, "url": "", "image": dest_image,
                "category": "", "description": "", "activities": []
            }
            continue

        lower_line = raw_line.lower()
        if lower_line.startswith("image:") or lower_line.startswith("photo:") or lower_line.startswith("img:"):
            img_val = raw_line.split(":", 1)[1].strip()
            if not current_entry:
                current_entry = {"name": "", "url": "", "image": "", "category": "", "description": "", "activities": []}
            current_entry["image"] = img_val
            continue
        elif lower_line.startswith("category:"):
            cat_val = raw_line.split(":", 1)[1].strip()
            if not current_entry:
                current_entry = {"name": "", "url": "", "image": "", "category": "", "description": "", "activities": []}
            current_entry["category"] = cat_val
            continue
        elif lower_line.startswith("desc:") or lower_line.startswith("description:"):
            desc_val = raw_line.split(":", 1)[1].strip()
            if not current_entry:
                current_entry = {"name": "", "url": "", "image": "", "category": "", "description": "", "activities": []}
            current_entry["description"] = desc_val
            continue

        if raw_line.startswith("http://") or raw_line.startswith("https://"):
            if not current_entry:
                current_entry = {"name": "", "url": "", "image": "", "category": "", "description": "", "activities": []}

            if is_direct_image_url(raw_line):
                if current_entry.get("url"):
                    current_entry["image"] = raw_line
                elif not current_entry.get("image"):
                    current_entry["image"] = raw_line
                else:
                    entries.append(current_entry)
                    current_entry = {"name": "", "url": "", "image": raw_line, "category": "", "description": "", "activities": []}
            else:
                if current_entry.get("url"):
                    entries.append(current_entry)
                    current_entry = {"name": "", "url": raw_line, "image": "", "category": "", "description": "", "activities": []}
                else:
                    current_entry["url"] = raw_line

    if current_entry and (current_entry.get("url") or current_entry.get("image")):
        entries.append(current_entry)

    resolved = []
    for idx, item in enumerate(entries):
        name = item.get("name", "").strip()
        url = item.get("url", "").strip()
        image = item.get("image", "").strip()

        if not name and url:
            name = extract_name_from_url(url)
        if not name:
            name = f"Destination {idx + 1}"

        resolved.append({
            "name": name, "url": url, "image": image,
            "category": item.get("category", ""),
            "description": item.get("description", ""),
            "activities": item.get("activities", [])
        })

    return resolved

def parse_txt_and_sync():
    dest_txt_path = os.path.join(_root_dir, "..", "..", "destinations.txt")
    if not os.path.exists(dest_txt_path):
        print(f"ERROR: File not found at {dest_txt_path}")
        return

    entries = parse_destinations_file(dest_txt_path)

    print(f"\n=======================================================")
    print(f"--- PARSED {len(entries)} DESTINATION(S) FROM destinations.txt ---")
    print(f"=======================================================")
    for i, item in enumerate(entries):
        resolved_img = get_exact_image_for_destination(item["name"], item["url"], item.get("image"))
        print(f"  {i+1}. {item['name']}")
        print(f"     Image: {resolved_img[:80]}...")

    init_db()
    clear_all_destinations()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    conn = get_connection()
    cur = conn.cursor()

    inserted = []
    for i, item in enumerate(entries):
        name = item["name"]
        raw_url = item["url"]
        explicit_image = item.get("image")

        meta = derive_metadata(name, raw_url)
        if item.get("category"):
            meta["category"] = item["category"]
        if item.get("description"):
            meta["desc"] = item["description"]

        dest_website = raw_url if "google.com/maps" in raw_url or raw_url.startswith("http") else meta["gmaps"]
        dest_image = get_exact_image_for_destination(name, raw_url, explicit_image)
        lat, lng = extract_coordinates_from_url(raw_url)

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
            lat,
            lng,
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
        inserted.append((dest_id, name, dest_image))

    conn.commit()
    cur.close()
    release_connection(conn)

    print(f"\nSUCCESS: Inserted {len(inserted)} destination(s) into local database.")
    for idx, name, img in inserted:
        print(f"  + {name} -> Image: {img}")

    local_db_path = os.path.join(_root_dir, "destinations.db")
    if os.path.exists(local_db_path):
        try:
            cmd = ["docker", "cp", local_db_path, "recommendation-service:/recommendation-service/destinations.db"]
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0:
                print("\nSUCCESS: Synced database directly into Docker container (recommendation-service)!")
            else:
                print(f"\nNotice: Docker sync status ({res.stderr.strip()}). Local database updated.")
        except Exception as e:
            print(f"\nNotice: Docker sync skipped ({e}).")

if __name__ == "__main__":
    parse_txt_and_sync()
