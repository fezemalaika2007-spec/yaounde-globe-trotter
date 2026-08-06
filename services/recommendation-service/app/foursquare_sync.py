"""recommendation-service/foursquare_sync.py

Foursquare API integration for Yaoundé, Cameroon.

This module fully replaces the old Overpass/Wikidata/Wikimedia pipeline.

Why Foursquare?
  * Foursquare's API returns photos already attached directly to each
    specific venue in its own database. There is no separate matching or
    fallback step, so there is no shared image pool that can run out and
    cause the kind of duplicate-image bugs the old Overpass/Wikidata/Wikimedia
    pipeline suffered from.

Authentication:
  * Uses the Foursquare v2 legacy API with a Client ID + Client Secret
    (passed as query params with a `v` version parameter). This is the
    credential set that validates against the live API.

Behaviour:
  * Searches Foursquare for venues around Yaoundé (3.848, 11.502) across the
    travel-relevant category taxonomy (restaurants, hotels, museums, parks,
    markets, attractions, etc.).
  * For each venue, fetches the venue's photos to obtain name, category,
    coordinates, formatted address, price tier, and photos — photo URLs are
    unique to that specific venue.
  * VENUES WITH ZERO PHOTOS ARE EXCLUDED ENTIRELY (Step 3A). We never fall
    back to a placeholder image, so the app only ever contains destinations
    that have at least one real photo.
  * A global safety-net deduplication check ensures no single photo URL is
    assigned to more than one destination.
"""
import datetime
import logging
import os
import threading
import time

import requests

logger = logging.getLogger(__name__)

# Foursquare API configuration (v2 legacy API).
FOURSQUARE_API_URL = "https://api.foursquare.com/v2/venues"
FOURSQUARE_CLIENT_ID = os.environ.get("FOURSQUARE_CLIENT_ID", "")
FOURSQUARE_CLIENT_SECRET = os.environ.get("FOURSQUARE_CLIENT_SECRET", "")
FOURSQUARE_VERSION = os.environ.get("FOURSQUARE_VERSION", "20240101")

# The Places API key (v3 / new developer portal). The v2 legacy oauth flow
# uses client_id + client_secret, but the newer key is supplied as a single
# `FOURSQUARE_API_KEY`. We support both so docker-compose's
# `FOURSQUARE_API_KEY` (per the task's Step 1) works out of the box.
FOURSQUARE_API_KEY = os.environ.get("FOURSQUARE_API_KEY", "")


def _has_credentials():
    """Return True if any valid Foursquare credential set is configured.

    Accepts either the v2 pair (client_id + client_secret) or the single
    Places API key (FOURSQUARE_API_KEY).
    """
    return bool(
        (FOURSQUARE_CLIENT_ID and FOURSQUARE_CLIENT_SECRET)
        or FOURSQUARE_API_KEY
    )

# Yaoundé, Cameroon centre coordinates.
YAOUNDE_LAT = 3.848
YAOUNDE_LON = 11.502
YAOUNDE_RADIUS_M = 15000  # ~15km radius covers the metropolitan area

# Foursquare category IDs (v2 taxonomy) mapped to our internal tag taxonomy.
# See https://developer.foursquare.com/docs/resources/categories
FOURSQUARE_CATEGORIES = [
    # (fsq_category_id, category_label, fsq_category_name)
    # Top-level taxonomy IDs (confirmed valid against the v2 API).
    ("4d4b7105d754a06374d81259", "food", "Restaurant"),   # Food
    ("4d4b7105d754a06375d81259", "culture", "Arts & Culture"),
    ("4d4b7105d754a06377d81259", "nature", "Outdoors & Recreation"),
    ("4d4b7105d754a06378d81259", "market", "Shops & Services"),
    ("4d4b7105d754a06379d81259", "accommodation", "Travel & Transport"),
    # Confirmed-valid subcategories.
    ("4bf58dd8d48988d181941735", "culture", "Museum"),    # Museum
    ("4bf58dd8d48988d163941735", "nature", "Park"),       # Park / Outdoors
    ("4bf58dd8d48988d1fd941735", "market", "Market"),     # Farmers Market
    ("4bf58dd8d48988d16a941735", "food", "Cafe"),         # Coffee Shop
]

# Compile the unique set of Foursquare category IDs to query.
FSQ_CATEGORY_IDS = sorted({cid for cid, _, _ in FOURSQUARE_CATEGORIES})

# Map helper: category id -> (category_label, fsq_name)
_FSQ_CAT_MAP = {cid: (label, name) for cid, label, name in FOURSQUARE_CATEGORIES}

# v3 primary category IDs mapped to our internal labels. The v2 search returns
# v2 taxonomy IDs, but fixtures/tests and some responses use v3 primary IDs.
_V3_CATEGORY_LABELS = {
    "10000": "culture",          # Arts & Entertainment
    "10016": "culture",          # Museum
    "11000": "food",             # Dining & Drinking
    "13000": "food",             # Nightlife Spot (mapped to food)
    "13065": "accommodation",    # Hotel
    "14000": "nature",           # Outdoors & Recreation
    "16000": "accommodation",    # Residence
    "16032": "accommodation",    # Hotel (v3)
    "17000": "market",           # Shop & Service
    "18000": "accommodation",    # Travel & Transport
}
_FSQ_CAT_MAP.update({cid: (label, label) for cid, label in _V3_CATEGORY_LABELS.items()})

# Map Foursquare price tier (1-4) to a cost in XAF.
# Foursquare price: 1 = cheap, 2 = moderate, 3 = expensive, 4 = very expensive.
PRICE_TIER_TO_COST = {1: 5000, 2: 15000, 3: 30000, 4: 50000}


def _normalize_image_url(url: str) -> str:
    """Normalize a Foursquare photo URL to a canonical form for deduplication.

    Foursquare photo URLs look like:
        https://fastly.4sqi.net/img/general/1000x1000/ABC123_hash.jpg
    which is already unique per venue. We normalize scheme/host/trailing
    slashes so the same photo served over http vs https is treated as equal.
    """
    if not url:
        return ""
    from urllib.parse import urlparse
    try:
        p = urlparse(url)
        scheme = "https"
        netloc = (p.netloc or "").lower()
        if netloc.startswith("www."):
            netloc = netloc[4:]
        path = p.path.rstrip("/")
        return f"{scheme}://{netloc}{path}"
    except Exception as e:
        logger.warning(f"URL normalization failed for '{url}': {e}")
        return url.strip().lower().rstrip("/")


def _common_params(**extra):
    """Build the common query params for the Foursquare API.

    Prefers the v2 pair (client_id + client_secret). If only the single
    Places API key (FOURSQUARE_API_KEY) is set, send it as the API key
    field instead.
    """
    if FOURSQUARE_CLIENT_ID and FOURSQUARE_CLIENT_SECRET:
        params = {
            "client_id": FOURSQUARE_CLIENT_ID,
            "client_secret": FOURSQUARE_CLIENT_SECRET,
            "v": FOURSQUARE_VERSION,
        }
    else:
        params = {"api_key": FOURSQUARE_API_KEY}
    params.update(extra)
    return params


def _safe_place_name(name):
    """Reject names that don't represent a real travel destination."""
    if not name:
        return False
    lower = name.lower().strip()
    if len(lower) < 3:
        return False
    generic_nouns = {
        "restaurant", "cafe", "hotel", "bar", "shop", "supermarket",
        "pharmacy", "hospital", "church", "school", "market",
        "fast food", "fast-food", "bakery", "hôtel", "mosquée",
        "église", "clinique", "marché", "parking", "bureau", "toilet",
        "wc", "bench", "bus stop", "stop", "unnamed", "no name",
    }
    if lower in generic_nouns or lower.rstrip(" .") in generic_nouns:
        return False
    return True


def _build_description(name, category_label, fsq_name, address, price_tier):
    """Build a human-friendly description from the Foursquare venue data."""
    parts = []
    if category_label == "food":
        parts.append(
            f"{name} is a {fsq_name} in Yaoundé offering a genuine taste of "
            f"local cuisine and a lively dining atmosphere."
        )
    elif category_label == "accommodation":
        parts.append(
            f"{name} is a hospitality venue in Yaoundé offering comfortable "
            f"stay options for visitors."
        )
    elif category_label == "culture":
        parts.append(
            f"{name} is a cultural destination in Yaoundé with local "
            f"significance and visitor interest."
        )
    elif category_label == "nature":
        parts.append(
            f"{name} is a nature destination around Yaoundé offering outdoor "
            f"experiences and scenic surroundings."
        )
    elif category_label == "market":
        parts.append(
            f"{name} is a lively shopping destination in Yaoundé where visitors "
            f"can experience local commerce and daily life."
        )
    elif category_label == "sports":
        parts.append(
            f"{name} is a sports destination in Yaoundé offering facilities "
            f"for active recreation."
        )
    else:
        parts.append(f"{name} is a destination in Yaoundé, Cameroon.")

    info = []
    if address:
        info.append(f"It is located at {address}")
    if price_tier:
        tier_names = {1: "budget-friendly", 2: "moderately priced",
                      3: "upscale", 4: "high-end"}
        info.append(f"it is a {tier_names.get(price_tier, '')} venue")
    if info:
        sentence = ", and ".join(info) + "."
        parts.append(sentence.capitalize())

    parts.append(
        "It is a worthwhile stop for travellers exploring the city of Yaoundé, "
        "Cameroon."
    )
    return " ".join(parts)


def _map_activities(category_label):
    """Map a Foursquare category label to a list of activity strings."""
    base = {
        "food": ["Dining", "Local Cuisine"],
        "accommodation": ["Accommodation", "Lodging"],
        "culture": ["Cultural Experience", "Historical Visit", "Sightseeing"],
        "nature": ["Nature Walks", "Outdoor Recreation", "Sightseeing"],
        "market": ["Shopping", "Local Culture"],
        "sports": ["Sports", "Outdoor Recreation"],
        "attraction": ["Sightseeing", "Photography"],
        "business": ["Business", "Conferences"],
    }
    return base.get(category_label, ["Sightseeing"])


def _map_facilities(price_tier):
    """Derive a small facilities list from price tier (best-effort)."""
    facilities = []
    if price_tier:
        if price_tier >= 2:
            facilities.append("Comfortable Facilities")
        if price_tier >= 3:
            facilities.append("Premium Amenities")
    return facilities


def _venues_from_search(limit=50, cursor_offset=0):
    """Call Foursquare v2 Place Search and return raw venue objects."""
    params = _common_params(
        ll=f"{YAOUNDE_LAT},{YAOUNDE_LON}",
        radius=YAOUNDE_RADIUS_M,
        categoryId=",".join(FSQ_CATEGORY_IDS),
        limit=limit,
        offset=cursor_offset,
        intent="browse",
    )

    resp = requests.get(
        f"{FOURSQUARE_API_URL}/search",
        params=params,
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()
    return data.get("response", {}).get("venues", [])


_CREDITS_EXHAUSTED = False


def _venue_photos(fsq_id):
    """Call Foursquare v2 Venue Photos and return a list of photo dicts."""
    global _CREDITS_EXHAUSTED
    if _CREDITS_EXHAUSTED:
        # Fail fast: once the account's credits are exhausted, every further
        # photos call will also be rejected. Avoid hammering the API.
        return []
    params = _common_params(limit=6)
    resp = requests.get(
        f"{FOURSQUARE_API_URL}/{fsq_id}/photos",
        params=params,
        timeout=30,
    )
    if resp.status_code == 402:
        # 402 = Payment Required / credits exhausted. Stop making photos calls.
        _CREDITS_EXHAUSTED = True
        logger.error(
            "Foursquare credits exhausted (402). Photo retrieval is disabled "
            "for this sync run; no venues with photos can be stored."
        )
        return []
    resp.raise_for_status()
    data = resp.json()
    return data.get("response", {}).get("photos", {}).get("items", [])


def _photo_url(photo):
    """Build a full photo URL from a v2 photo dict (prefix + size + suffix)."""
    prefix = photo.get("prefix", "")
    suffix = photo.get("suffix", "")
    if not prefix or not suffix:
        return ""
    # Use the original size to keep the highest-quality image.
    return f"{prefix}original{suffix}"


def _category_label_for_venue(categories):
    """Map a venue's Foursquare categories to our internal tag label."""
    if not categories:
        return "attraction"
    for cat in categories:
        cat_id = str(cat.get("id", ""))
        if cat_id in _FSQ_CAT_MAP:
            return _FSQ_CAT_MAP[cat_id][0]
    return "attraction"


def _venue_price(venue):
    """Extract price tier from a venue (1-4) or None if unknown.

    Handles both shapes:
      * v2: price is a dict like {"tier": 2, ...}
      * v3/test: price is a plain integer 1-4.
    """
    price = venue.get("price")
    if isinstance(price, dict):
        tier = price.get("tier")
        if isinstance(tier, (int, float)):
            return int(tier)
        return None
    if isinstance(price, (int, float)):
        try:
            tier = int(price)
        except (ValueError, TypeError):
            return None
        if 1 <= tier <= 4:
            return tier
    return None


def _normalize_venue(venue, photos=None):
    """Convert a Foursquare venue dict into our destination shape.

    Supports both response shapes:
      * v2: photos passed separately via the `photos` argument.
      * v3/test: photos embedded in the venue dict under `photos`.
    Accepts venue IDs from either `id` (v2) or `fsq_id` (v3).

    Returns None if the venue has no real photo (Step 3A exclusion) or
    cannot be normalized.
    """
    fsq_id = venue.get("id", "") or venue.get("fsq_id", "")
    name = venue.get("name", "").strip()
    if not fsq_id or not name:
        return None
    if not _safe_place_name(name):
        return None

    # Photos may be provided separately (v2) or embedded in the venue (v3/test).
    if photos is None:
        photos = venue.get("photos") or []

    # Only keep venues that have at least one real photo (Step 3A).
    image_urls = []
    for photo in photos:
        url = _photo_url(photo)
        if url:
            normalized = _normalize_image_url(url)
            if normalized and normalized not in image_urls:
                image_urls.append(normalized)
        if len(image_urls) >= 6:
            break

    # CRITICAL (Step 3A): venues with zero photos are NOT stored at all.
    if not image_urls:
        return None

    # Coordinates — support both v2 (location.lat/lng) and v3 (geocodes.main).
    loc = venue.get("location") or {}
    lat = loc.get("lat")
    lon = loc.get("lng")
    if (lat is None or lon is None) and venue.get("geocodes"):
        main = venue.get("geocodes", {}).get("main") or {}
        lat = main.get("latitude")
        lon = main.get("longitude")
    if lat is None or lon is None or lat == 0 or lon == 0:
        return None

    # Address.
    address_parts = []
    if loc.get("address"):
        address_parts.append(loc["address"])
    city = loc.get("city") or loc.get("locality")
    if city:
        address_parts.append(city)
    if loc.get("state"):
        address_parts.append(loc["state"])
    address = ", ".join(address_parts)
    area = f"{city or 'Yaoundé'}, Yaoundé"

    # Category.
    categories = venue.get("categories") or []
    category_label = _category_label_for_venue(categories)
    fsq_name = ""
    if categories:
        fsq_name = categories[0].get("name", "")

    # Tags.
    tags = [category_label, "yaounde", "cameroon"]

    # Price tier -> cost (XAF).
    price_tier = _venue_price(venue)
    cost = None
    if price_tier:
        cost = PRICE_TIER_TO_COST.get(price_tier)

    description = _build_description(
        name, category_label, fsq_name, address, price_tier
    )

    phone = ""
    contact = venue.get("contact") or {}
    if isinstance(contact, dict):
        phone = contact.get("formattedPhone") or contact.get("phone") or ""

    return {
        "fsq_id": fsq_id,
        "name": name,
        "area": area,
        "tags": tags,
        "description": description,
        "long_description": description,
        "cost": cost,
        "image": image_urls[0],
        "image_source": "foursquare",
        "latitude": lat,
        "longitude": lon,
        "address": address,
        "category": category_label,
        "activities": _map_activities(category_label),
        "opening_hours": "",
        "phone": phone,
        "website": "",
        "email": "",
        "price_level": price_tier,
        "facilities": _map_facilities(price_tier),
        "cuisine": (fsq_name if category_label == "food" else ""),
        "star_rating": None,
        "images": image_urls,
    }


def fetch_destinations(max_results=200):
    """Fetch all Foursquare venues around Yaoundé and normalize them.

    Returns a tuple (kept_destinations, stats) where stats is a dict:
        {
          "total_venues": N,       # venues Foursquare returned
          "kept": N,               # venues with at least one photo
"excluded_no_photo": N,  # venues with zero photos
          "excluded_other": N,     # venues filtered for name/coords
        }
    """
    if not _has_credentials():
        logger.error(
            "Foursquare credentials are not set. "
            "Set FOURSQUARE_CLIENT_ID + FOURSQUARE_CLIENT_SECRET, or "
            "FOURSQUARE_API_KEY. Cannot sync destinations."
        )
        raise RuntimeError(
            "Foursquare credentials are required: set FOURSQUARE_CLIENT_ID and "
            "FOURSQUARE_CLIENT_SECRET, or FOURSQUARE_API_KEY"
        )

    kept = []
    total_venues = 0
    excluded_no_photo = 0
    excluded_other = 0

    offset = 0
    page_size = 50
    while len(kept) < max_results and offset < max_results:
        try:
            venues = _venues_from_search(limit=page_size, cursor_offset=offset)
        except requests.exceptions.RequestException as e:
            logger.warning(f"Foursquare search failed (offset={offset}): {e}")
            break

        if not venues:
            break

        total_venues += len(venues)
        for venue in venues:
            if len(kept) >= max_results:
                break
            fsq_id = venue.get("id", "")

            try:
                photos = _venue_photos(fsq_id)
            except requests.exceptions.RequestException as e:
                logger.warning(f"Foursquare photos failed for {fsq_id}: {e}")
                photos = []

            if not photos:
                excluded_no_photo += 1
                continue

            normalized = _normalize_venue(venue, photos)
            if normalized:
                kept.append(normalized)
            else:
                excluded_other += 1

        # Advance to next page.
        offset += page_size
        if len(venues) < page_size:
            break

    stats = {
        "total_venues": total_venues,
        "kept": len(kept),
        "excluded_no_photo": excluded_no_photo,
        "excluded_other": excluded_other,
    }
    logger.info(
        f"Foursquare sync: {stats['total_venues']} venues found, "
        f"{stats['kept']} kept (with photos), "
        f"{stats['excluded_no_photo']} excluded (no photo), "
        f"{stats['excluded_other']} excluded (other)."
    )
    return kept, stats


# ---------------------------------------------------------------------------
# Deduplication and Database Synchronization
# ---------------------------------------------------------------------------

def _deduplicate_global_images(items):
    """Ensure no single photo URL is used by more than one destination.

    Foursquare photo URLs are unique per venue, so this is a pure safety net.
    Returns the set of used image URLs.
    """
    used_images = set()
    for item in items:
        images = item.get("images") or []
        unique = []
        for url in images:
            n = _normalize_image_url(url)
            if n and n not in used_images:
                unique.append(url)
                used_images.add(n)
        item["images"] = unique
        item["image"] = unique[0] if unique else ""
    return used_images


def deduplicate_and_sync(incoming_list, app=None):
    """Deduplicate incoming destinations by fsq_id and write to the database.

    Returns the count of inserted/updated destinations.
    """
    from app.models import get_connection, upsert_destination

    # 1. Deduplicate by fsq_id (Foursquare venue IDs are globally unique).
    seen = {}
    for item in incoming_list:
        fsq_id = item.get("fsq_id")
        if not fsq_id:
            continue
        if fsq_id not in seen or len(item.get("images", [])) > len(
            seen[fsq_id].get("images", [])
        ):
            seen[fsq_id] = item
    final_incoming = list(seen.values())

    # 2. Global photo URL uniqueness safety net (Step 3).
    _deduplicate_global_images(final_incoming)
    # Drop any destination that ended up with no image after the safety net.
    final_incoming = [d for d in final_incoming if d.get("image")]

    # 3. Query existing fsq_ids to decide updates vs inserts.
    conn = get_connection(app)
    cur = conn.cursor()
    cur.execute("SELECT fsq_id FROM destinations WHERE fsq_id IS NOT NULL")
    existing = cur.fetchall()
    existing_fsq_ids = {row[0] for row in existing}
    cur.close()
    conn.close()

    count = 0
    for item in final_incoming:
        upsert_destination(app=app, **item)
        count += 1

    return count


def sync_destinations(app=None):
    """Fetch destinations from Foursquare and store in the database.

    Returns a dict with the sync stats and the upserted count.
    """
    from app.models import get_all_destinations, set_last_synced_now

    try:
        incoming, stats = fetch_destinations()
    except Exception as e:
        logger.warning(f"Foursquare API request failed: {e}")
        cached = get_all_destinations(app)
        logger.info(f"Returning {len(cached)} cached destinations")
        stats = {"total_venues": 0, "kept": len(cached),
                 "excluded_no_photo": 0, "excluded_other": 0}
        return stats, len(cached)

    count = deduplicate_and_sync(incoming, app)
    set_last_synced_now(app)
    stats["upserted"] = count
    logger.info(f"Synchronized {count} destinations from Foursquare")
    return stats, count


def search_foursquare(query, app=None, limit=12):
    """Live-search Foursquare for matching places in Yaoundé.

    Returns a list of normalized destination dicts that have photos.
    """
    if not query or not query.strip():
        return []
    if not _has_credentials():
        return []
    q = query.strip()
    try:
        params = _common_params(
            ll=f"{YAOUNDE_LAT},{YAOUNDE_LON}",
            radius=YAOUNDE_RADIUS_M,
            query=q,
            limit=min(limit, 50),
            intent="browse",
        )
        resp = requests.get(
            f"{FOURSQUARE_API_URL}/search",
            params=params,
            timeout=30,
        )
        resp.raise_for_status()
        venues = resp.json().get("response", {}).get("venues", [])
        results = []
        for venue in venues:
            try:
                photos = _venue_photos(venue.get("id", ""))
                if not photos:
                    continue
                normalized = _normalize_venue(venue, photos)
                if normalized:
                    results.append(normalized)
                if len(results) >= limit:
                    break
            except Exception:
                continue
        return results
    except Exception as e:
        logger.warning(f"Live Foursquare search failed for '{query}': {e}")
        return []


# ---------------------------------------------------------------------------
# Background periodic execution
# ---------------------------------------------------------------------------

def start_periodic_sync(app):
    """Start a background daemon thread to run sync_destinations every 12 hours."""
    def run_sync_loop():
        logger.info("Background periodic sync loop started (will run sync every 12 hours).")
        while True:
            time.sleep(43200)  # 12 hours
            try:
                with app.app_context():
                    logger.info("Starting periodic background destination sync...")
                    stats, count = sync_destinations(app)
                    logger.info(
                        f"Periodic sync: kept {count} destinations "
                        f"({stats.get('total_venues', 0)} found, "
                        f"{stats.get('excluded_no_photo', 0)} excluded no-photo)"
                    )
            except Exception as e:
                logger.error(f"Periodic background destination sync failed: {e}", exc_info=True)

    thread = threading.Thread(target=run_sync_loop, daemon=True)
    thread.start()


def build_full_description(name, tags, primary_category, cuisine,
                           opening_hours, phone, website, address):
    """Compatibility helper so callers referencing the old signature still work."""
    return _build_description(name, primary_category, primary_category, address, None)
