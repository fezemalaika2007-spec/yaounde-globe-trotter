"""recommendation-service/overpass_sync.py

OpenStreetMap Overpass API integration for Yaoundé, Cameroon.

This module fetches real points of interest from the free Overpass API
(https://overpass-api.de/api/interpreter) and normalizes them into the
destination shape used by the app. No API key required — Overpass is public.

The sync is triggered via POST /sync-destinations or automatically at startup.
Proper caching (Redis) is a Phase 4 concern — for now we cache in the
SQLite database with a last_synced_at timestamp.

Overpass Query: Fetches tourism and amenity tags within a bounding box
around Yaoundé (lat ~3.848, lon ~11.502).
"""
import json
import logging
import time
import requests
from app.image_utils import fetch_wikimedia_image, get_placeholder_image

logger = logging.getLogger(__name__)

# Bounding box for Yaoundé, Cameroon (south, west, north, east)
# Covers the city center and immediate suburbs
YAOUNDE_BBOX = "3.78,11.42,3.92,11.58"
OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# OSM tags that map to travel-relevant categories
# Each tag is a tuple: (key, value_or_None, category_label)
RELEVANT_TAGS = [
    ("tourism", "museum", "culture"),
    ("tourism", "hotel", "accommodation"),
    ("tourism", "viewpoint", "nature"),
    ("tourism", "zoo", "nature"),
    ("tourism", "gallery", "culture"),
    ("tourism", "attraction", "culture"),
    ("amenity", "restaurant", "food"),
    ("amenity", "cafe", "food"),
    ("amenity", "marketplace", "market"),
    ("amenity", "theatre", "culture"),
    ("amenity", "library", "culture"),
    ("amenity", "place_of_worship", "culture"),
    ("amenity", "park", "nature"),
    ("leisure", "park", "nature"),
    ("leisure", "garden", "nature"),
    ("leisure", "stadium", "sports"),
    ("historic", None, "culture"),
    ("natural", "peak", "nature"),
    ("natural", "water", "nature"),
    ("shop", "mall", "market"),
]


def _build_overpass_query():
    """Build the Overpass QL query string for Yaoundé POIs."""
    # We use a simple 'node' query for points of interest
    # and fetch tags that are relevant to travelers
    tag_filters = []
    for key, value, _ in RELEVANT_TAGS:
        if value:
            tag_filters.append(f'["{key}"="{value}"]')
        else:
            tag_filters.append(f'["{key}"]')

    # Combine all tag filters with OR logic using a union block
    tag_filters_str = "\n    ".join(
        f'  node{filter}({YAOUNDE_BBOX});'
        for filter in tag_filters
    )

    query = f"""
[out:json][timeout:30];
(
{tag_filters_str}
);
out body;
"""
    return query.strip()


def _normalize_osm_element(element):
    """Convert an OSM element dict into our destination shape.

    Returns None if the element can't be normalized (no name).
    """
    tags = element.get("tags", {})
    osm_id = f"{element['type']}/{element['id']}"
    name = tags.get("name", "").strip()

    if not name:
        return None  # Skip unnamed elements

    # Determine primary tag/category
    primary_tag = "attraction"
    for key, value, category in RELEVANT_TAGS:
        if value:
            if tags.get(key) == value:
                primary_tag = category
                break
        else:
            if key in tags:
                primary_tag = category
                break

    # Build normalized tags list
    tag_set = set()
    tag_set.add(primary_tag)
    for key, value, category in RELEVANT_TAGS:
        if value:
            if tags.get(key) == value:
                tag_set.add(category)
        else:
            if key in tags:
                tag_set.add(category)

    # Generate description from available tags
    description = tags.get("description", "")
    if not description:
        parts = []
        if tags.get("cuisine"):
            parts.append(f"Serves {tags['cuisine']} cuisine")
        if tags.get("opening_hours"):
            parts.append(f"Open: {tags['opening_hours']}")
        if tags.get("phone"):
            parts.append(f"Contact: {tags['phone']}")
        if tags.get("website"):
            parts.append(f"Website available")
        if parts:
            description = f"{name} — {' | '.join(parts)}."
        else:
            description = f"A {primary_tag} destination in Yaoundé, Cameroon."

    # Cost — most OSM entries won't have pricing, mark null
    cost = None

    # Image — try Wikidata/Wikimedia first, fall back to placeholder
    wikidata_id = tags.get("wikidata", "")
    wikipedia = tags.get("wikipedia", "")
    image = ""
    image_source = "placeholder"

    if wikidata_id or wikipedia:
        fetched_image, verified = fetch_wikimedia_image(
            wikidata_id=wikidata_id,
            wikipedia_title=wikipedia,
            place_name=name
        )
        if fetched_image and verified:
            image = fetched_image
            image_source = "wikimedia"

    if not image:
        image = get_placeholder_image(primary_tag)
        image_source = "placeholder"

    # Location area
    area = tags.get("addr:city", "Yaoundé")
    if tags.get("addr:suburb"):
        area = f"{tags['addr:suburb']}, Yaoundé"

    return {
        "osm_id": osm_id,
        "name": name,
        "area": area,
        "tags": list(tag_set),
        "description": description,
        "cost": cost,
        "image": image,
        "image_source": image_source,
    }


def sync_destinations(app=None):
    """Fetch destinations from Overpass API and store in database.

    Returns the count of new/updated destinations on success.
    Handles Overpass being slow or unavailable gracefully by returning
    the last successfully cached data instead of erroring out.
    """
    from app.models import get_all_destinations, upsert_destination, set_last_synced_now

    query = _build_overpass_query()
    logger.info("Querying Overpass API for Yaoundé POIs...")

    try:
        response = requests.get(
            OVERPASS_URL,
            params={"data": query},
            timeout=30,
            headers={"User-Agent": "YaoundeGlobeTrotter/1.0"}
        )
        response.raise_for_status()
        data = response.json()
    except requests.exceptions.RequestException as e:
        logger.warning(f"Overpass API request failed: {e}")
        # Return cached data count
        cached = get_all_destinations(app)
        logger.info(f"Returning {len(cached)} cached destinations")
        return len(cached) if cached else 0

    elements = data.get("elements", [])
    logger.info(f"Overpass returned {len(elements)} elements")

    count = 0
    for element in elements:
        normalized = _normalize_osm_element(element)
        if normalized is None:
            continue

        upsert_destination(
            osm_id=normalized["osm_id"],
            name=normalized["name"],
            area=normalized["area"],
            tags=normalized["tags"],
            description=normalized["description"],
            cost=normalized["cost"],
            image=normalized["image"],
            image_source=normalized["image_source"],
            app=app,
        )
        count += 1

    set_last_synced_now(app)
    logger.info(f"Synchronized {count} destinations from Overpass")
    return count
