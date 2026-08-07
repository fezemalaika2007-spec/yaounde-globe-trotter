"""recommendation-service/foursquare_sync.py

Foursquare Places API (v3) integration for Yaoundé, Cameroon.

This module fully replaces the old Overpass/Wikidata/Wikimedia pipeline.

Why the v3 Places API?
  * Foursquare's Places API returns photos already attached directly to each
    specific venue. There is no separate matching or fallback step, so there
    is no shared image pool that can run out and cause duplicate images.
  * The v3 API authenticates with a single API key sent as a Bearer token
    (Authorization: Bearer <FOURSQUARE_API_KEY>) — exactly the key format the
    task's Step 1 asked to store in the FOURSQUARE_API_KEY env var.

Behaviour:
  * Searches for venues around Yaoundé (3.848, 11.502) across travel-relevant
    categories (restaurants, hotels, museums, parks, markets, attractions...).
  * For each venue, fetches its photos and normalizes name, category,
    coordinates, address, price tier, and photo URLs.
  * VENUES WITH ZERO PHOTOS ARE EXCLUDED ENTIRELY (Step 3A) — no placeholders.
  * A global safety-net check ensures no photo URL is used more than once.
"""
import logging
import os
import threading
import time

import requests

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Foursquare Places API (v3) configuration
# ---------------------------------------------------------------------------
FOURSQUARE_API_URL = os.environ.get(
    "FOURSQUARE_API_URL", "https://api.foursquare.com/v3/places"
)
FOURSQUARE_API_KEY = os.environ.get("FOURSQUARE_API_KEY", "")

# Yaoundé, Cameroon centre coordinates.
YAOUNDE_LAT = 3.848
YAOUNDE_LON = 11.502
YAOUNDE_RADIUS_M = 20000  # ~20km radius covers the metropolitan area and suburbs

# v3 category IDs mapped to our internal tag taxonomy.
# See https://location.foursquare.com/developer/reference/category-tree
_FSQ_TO_TAG = {
    # Arts & Entertainment (10000)
    "10000": "culture",
    "10001": "culture",       # Performing Arts Venue
    "10016": "culture",       # Museum
    "10024": "culture",       # Art Gallery
    "10034": "culture",       # Museum
    "10035": "culture",       # Art Gallery
    "10050": "culture",       # History / Heritage
    # Dining & Drinking (11000)
    "11000": "food",
    "12000": "food",
    "12003": "food",          # Restaurant
    "12014": "food",          # Food Truck
    "12051": "food",          # Snack Place
    "12064": "food",          # Cafe / Coffee Shop
    "12067": "food",          # Bakery
    "12070": "food",          # Bakery
    # Nightlife (13000)
    "13000": "attraction",
    "13003": "attraction",    # Night club
    "13005": "attraction",    # General Entertainment
    "13007": "attraction",    # Entertainment
    "13065": "accommodation", # Hotel
    # Outdoors & Recreation (14000)
    "14000": "nature",
    "14001": "nature",        # Park
    "14002": "nature",        # Sports Venue / field
    "14003": "nature",        # Plaza
    "14004": "nature",        # Natural Feature
    "14011": "nature",        # Garden
    # Residence (16000)
    "16000": "accommodation",
    "16032": "accommodation", # Hotel
    "16063": "accommodation", # Guest House
    # Shop & Service (17000)
    "17000": "market",
    "17001": "market",        # Market
    "17069": "market",        # Farmers Market
    "17114": "market",        # Shopping Mall
    # Travel & Transport (18000)
    "18000": "accommodation",
    "18004": "accommodation", # Hotel
    "18056": "accommodation", # Transit / Station
    # Professional & Other Places (19000)
    "19000": "services",
    "19001": "services",
}

# Category IDs passed to the search request (travel-relevant subset).
FSQ_CATEGORY_IDS = [
    "10000", "10024", "10034",       # culture / museums / galleries
    "11000", "12003", "12014",       # dining
    "12051", "12064", "12067",       # cafes / bakeries / snacks
    "13065",                         # hotels
    "14000", "14001", "14002",       # nature / parks / sports
    "14003", "14004", "14011",
    "16032", "16063",                # hotels / guest houses
    "17000", "17001", "17069",       # markets / malls
    "17114",
    "18000", "18004",
]

# Map Foursquare price tier (1-4) to a cost in XAF.
PRICE_TIER_TO_COST = {1: 5000, 2: 15000, 3: 30000, 4: 50000}

# Search fields we request inline so each venue may carry its own photos.
SEARCH_FIELDS = (
    "fsq_id,name,geocodes,location,categories,price,contact,photos"
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _normalize_image_url(url: str) -> str:
    """Normalize a Foursquare photo URL to a canonical dedup form."""
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


def _has_credentials() -> bool:
    """Return True if the Foursquare Places API key is configured."""
    return bool(FOURSQUARE_API_KEY)


def _common_headers() -> dict:
    """Build the auth headers for the v3 Places API."""
    return {
        "Authorization": f"Bearer {FOURSQUARE_API_KEY}",
        "Accept": "application/json",
    }


def _safe_place_name(name) -> bool:
    """Reject names that aren't a real travel destination."""
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
    """Build a human-friendly description from Foursquare venue data."""
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
    """Map a category label to a list of activity strings."""
    base = {
        "food": ["Dining", "Local Cuisine"],
        "accommodation": ["Accommodation", "Lodging"],
        "culture": ["Cultural Experience", "Historical Visit", "Sightseeing"],
        "nature": ["Nature Walks", "Outdoor Recreation", "Sightseeing"],
        "market": ["Shopping", "Local Culture"],
        "sports": ["Sports", "Outdoor Recreation"],
        "attraction": ["Sightseeing", "Photography"],
        "services": ["Local Services"],
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


def _should_raise_for_status(resp):
    """Raise a clear, actionable error on bad status codes."""
    if resp.status_code in (401, 403):
        raise PermissionError(
            "Foursquare v3 auth failed (401/403). Check FOURSQUARE_API_KEY."
        )
    if resp.status_code == 402:
        raise PermissionError("Foursquare credits exhausted (402).")
    resp.raise_for_status()


def _extract_photos(venue):
    """Return a list of photos from a venue dict (v3 shape or inline)."""
    photos = venue.get("photos")
    if isinstance(photos, dict):
        return photos.get("items", []) or []
    if isinstance(photos, list):
        return photos
    return []


def _photo_url(photo):
    """Build a full, high-res photo URL from a v3 photo dict."""
    prefix = photo.get("prefix", "")
    suffix = photo.get("suffix", "")
    if not prefix or not suffix:
        return ""
    return f"{prefix}original{suffix}"


def _category_label_for_venue(categories):
    """Map a venue's v3 categories to our internal tag label."""
    if not categories:
        return "attraction"
    for cat in categories:
        cat_id = str(cat.get("id", ""))
        if cat_id in _FSQ_TO_TAG:
            return _FSQ_TO_TAG[cat_id]
        name = " ".join([
            cat.get("name", ""),
            cat.get("short_name", ""),
        ]).lower()
        if any(k in name for k in ("museum", "gallery", "cultural", "monument", "historic")):
            return "culture"
        if any(k in name for k in ("restaurant", "cafe", "coffee", "food", "bakery", "dining")):
            return "food"
        if any(k in name for k in ("park", "garden", "outdoor", "nature", "scenic", "plaza")):
            return "nature"
        if any(k in name for k in ("hotel", "resort", "hostel", "guest", "lodging")):
            return "accommodation"
        if any(k in name for k in ("market", "shop", "store", "mall", "marketplace")):
            return "market"
        if any(k in name for k in ("stadium", "sports", "gym", "field", "recreation")):
            return "sports"
        if any(k in name for k in ("attraction", "tourist", "landmark", "entertainment")):
            return "attraction"
    return "attraction"


def _venue_price(venue):
    """Extract price tier (1-4) or None. Handles int or dict shapes."""
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


def _coords_from_venue(venue):
    """Return (lat, lon) from a v3 venue, or (None, None)."""
    geocodes = venue.get("geocodes") or {}
    main = geocodes.get("main") or {}
    lat = main.get("latitude")
    lon = main.get("longitude")
    if lat is None or lon is None:
        loc = venue.get("location") or {}
        lat = loc.get("lat")
        lon = loc.get("lng")
    if lat is None or lon is None:
        return None, None
    try:
        lat = float(lat)
        lon = float(lon)
    except (ValueError, TypeError):
        return None, None
    if lat == 0 or lon == 0:
        return None, None
    return lat, lon


def _address_from_venue(venue):
    """Build a formatted address string from a v3 venue."""
    loc = venue.get("location") or {}
    if loc.get("formatted_address"):
        return loc["formatted_address"]
    parts = []
    if loc.get("address"):
        parts.append(loc["address"])
    if loc.get("locality") or loc.get("city"):
        parts.append(loc.get("locality") or loc.get("city"))
    if loc.get("region") or loc.get("state"):
        parts.append(loc.get("region") or loc.get("state"))
    return ", ".join([p for p in parts if p])


# ---------------------------------------------------------------------------
# API calls
# ---------------------------------------------------------------------------

def _venues_from_search(limit=50, cursor_offset=0):
    """Call the v3 Place Search endpoint and return raw venue objects."""
    params = {
        "ll": f"{YAOUNDE_LAT},{YAOUNDE_LON}",
        "radius": YAOUNDE_RADIUS_M,
        "categories": ",".join(FSQ_CATEGORY_IDS),
        "limit": min(limit, 50),
        "sort": "RELEVANCE",
        "fields": SEARCH_FIELDS,
    }
    if cursor_offset:
        params["cursor"] = str(cursor_offset)

    resp = requests.get(
        f"{FOURSQUARE_API_URL}/search",
        params=params,
        headers=_common_headers(),
        timeout=60,
    )
    _should_raise_for_status(resp)
    data = resp.json()
    return data.get("results", [])


_CREDITS_EXHAUSTED = False


def _venue_photos(fsq_id):
    """Call the v3 Place Photos endpoint and return photo dicts."""
    global _CREDITS_EXHAUSTED
    if _CREDITS_EXHAUSTED:
        return []
    resp = requests.get(
        f"{FOURSQUARE_API_URL}/{fsq_id}/photos",
        params={"limit": 6},
        headers=_common_headers(),
        timeout=30,
    )
    if resp.status_code == 402:
        _CREDITS_EXHAUSTED = True
        logger.error(
            "Foursquare credits exhausted (402). Photo retrieval disabled "
            "for this sync run; no venues with photos can be stored."
        )
        return []
    _should_raise_for_status(resp)
    data = resp.json()
    return data.get("photos", [])


# ---------------------------------------------------------------------------
# Normalization
# ---------------------------------------------------------------------------

def _normalize_venue(venue, photos=None):
    """Convert a v3 venue dict into our destination shape.

    Returns None if the venue has no photo (Step 3A) or can't be normalized.
    """
    fsq_id = venue.get("fsq_id", "") or venue.get("id", "")
    name = (venue.get("name", "") or "").strip()
    if not fsq_id or not name:
        return None
    if not _safe_place_name(name):
        return None

    if photos is None:
        photos = _extract_photos(venue)

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

    if not image_urls:
        return None

    lat, lon = _coords_from_venue(venue)
    if lat is None or lon is None:
        return None

    address = _address_from_venue(venue)
    loc = venue.get("location") or {}
    locality = loc.get("locality") or loc.get("city") or "Yaoundé"
    area = f"{locality}, Yaoundé"

    categories = venue.get("categories") or []
    category_label = _category_label_for_venue(categories)
    fsq_name = categories[0].get("name", "") if categories else ""

    tags = [category_label, "yaounde", "cameroon"]

    price_tier = _venue_price(venue)
    cost = PRICE_TIER_TO_COST.get(price_tier) if price_tier else None

    description = _build_description(
        name, category_label, fsq_name, address, price_tier
    )

    phone = ""
    contact = venue.get("contact") or {}
    if isinstance(contact, dict):
        phone = contact.get("phone") or contact.get("formattedPhone") or ""

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
    """Fetch Foursquare venues around Yaoundé and normalize them.

    Returns (kept_destinations, stats) where stats is a dict with
    total_venues / kept / excluded_no_photo / excluded_other.
    """
    if not _has_credentials():
        logger.error(
            "Foursquare credentials are not set. Set FOURSQUARE_API_KEY. "
            "Cannot sync destinations."
        )
        raise RuntimeError(
            "Foursquare credentials are required: set FOURSQUARE_API_KEY"
        )

    kept = []
    total_venues = 0
    excluded_no_photo = 0
    excluded_other = 0

    limit = 50
    cursor_offset = 0
    while len(kept) < max_results:
        try:
            venues = _venues_from_search(limit=limit, cursor_offset=cursor_offset)
        except requests.exceptions.RequestException as e:
            logger.warning(f"Foursquare search failed (cursor={cursor_offset}): {e}")
            break
        except PermissionError as e:
            logger.error(f"Foursquare auth/credits error: {e}")
            raise

        if not venues:
            break

        total_venues += len(venues)
        for venue in venues:
            if len(kept) >= max_results:
                break
            fsq_id = venue.get("fsq_id", "") or venue.get("id", "")

            photos = _extract_photos(venue)
            if not photos and fsq_id:
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

        cursor_offset += limit
        if len(venues) < limit:
            break
        if cursor_offset >= max_results:
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
    """Ensure no single photo URL is used by more than one destination."""
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
    """Deduplicate incoming destinations by fsq_id and write to the DB.

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
    """Fetch destinations from Foursquare and store them in the database.

    Returns (stats_dict, upserted_count). On failure returns cached data.
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
        params = {
            "ll": f"{YAOUNDE_LAT},{YAOUNDE_LON}",
            "radius": YAOUNDE_RADIUS_M,
            "query": q,
            "limit": min(limit, 50),
            "fields": SEARCH_FIELDS,
        }
        resp = requests.get(
            f"{FOURSQUARE_API_URL}/search",
            params=params,
            headers=_common_headers(),
            timeout=30,
        )
        _should_raise_for_status(resp)
        venues = resp.json().get("results", [])
        results = []
        for venue in venues:
            try:
                fsq_id = venue.get("fsq_id", "") or venue.get("id", "")
                photos = _extract_photos(venue)
                if not photos and fsq_id:
                    photos = _venue_photos(fsq_id)
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
