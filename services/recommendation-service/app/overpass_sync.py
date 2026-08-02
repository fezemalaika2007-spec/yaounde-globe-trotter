"""recommendation-service/overpass_sync.py

OpenStreetMap Overpass API integration for Yaoundé, Cameroon.
Fetches real destinations (nodes, ways, and relations), normalizes them,
deduplicates them, and stores them in SQLite.
Supports periodic background synchronization.
"""
import json
import logging
import time
import datetime
import requests
import threading
from app.image_utils import fetch_wikimedia_image, get_placeholder_image
from urllib.parse import urlparse, urlunparse

logger = logging.getLogger(__name__)

# Bounding box for Yaoundé, Cameroon (expanded to cover metropolitan area, suburbs, and outskirts)
YAOUNDE_BBOX = "3.65,11.20,4.15,11.75"
OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# Expanded travel-relevant categories and tags mapping
# Each tuple: (key, value_or_None, category_label)
RELEVANT_TAGS = [
    ("tourism", "museum", "culture"),
    ("tourism", "hotel", "accommodation"),
    ("tourism", "viewpoint", "nature"),
    ("tourism", "zoo", "nature"),
    ("tourism", "gallery", "culture"),
    ("tourism", "attraction", "culture"),
    ("tourism", "guest_house", "accommodation"),
    ("tourism", "hostel", "accommodation"),
    ("tourism", "motel", "accommodation"),
    ("tourism", "camp_site", "accommodation"),
    ("tourism", "information", "culture"),
    ("tourism", "monument", "culture"),
    
    ("amenity", "restaurant", "food"),
    ("amenity", "cafe", "food"),
    ("amenity", "marketplace", "market"),
    ("amenity", "theatre", "culture"),
    ("amenity", "library", "culture"),
    ("amenity", "place_of_worship", "culture"),
    ("amenity", "park", "nature"),
    ("amenity", "cinema", "culture"),
    ("amenity", "fast_food", "food"),
    ("amenity", "arts_centre", "culture"),
    
    ("leisure", "park", "nature"),
    ("leisure", "garden", "nature"),
    ("leisure", "stadium", "sports"),
    ("leisure", "sports_centre", "sports"),
    ("leisure", "playground", "sports"),
    ("leisure", "nature_reserve", "nature"),
    
    ("historic", None, "culture"),
    ("natural", "peak", "nature"),
    ("natural", "water", "nature"),
    
    ("shop", "mall", "market"),
    ("shop", "department_store", "market"),
    ("shop", "supermarket", "market"),
    ("shop", "convenience", "market"),
    ("shop", "bakery", "food"),
    
    ("amenity", "pharmacy", "health"),
    ("amenity", "hospital", "health"),
    ("amenity", "clinic", "health"),
    ("amenity", "bank", "finance"),
    ("amenity", "bureau_de_change", "finance"),
    ("amenity", "post_office", "services"),
    ("amenity", "taxi", "transport"),
    ("amenity", "bus_station", "transport"),
    ("amenity", "ferry_terminal", "transport"),
    ("amenity", "conference_centre", "business"),
    ("amenity", "community_centre", "culture"),
    ("amenity", "events_venue", "culture"),
    ("amenity", "internet_cafe", "services"),
    ("amenity", "car_wash", "services"),
    
    ("leisure", "marina", "nature"),
    ("leisure", "dog_park", "nature"),
    ("leisure", "fishing", "nature"),
    ("leisure", "ice_rink", "sports"),
    ("leisure", "miniature_golf", "sports"),
    ("leisure", "fitness_centre", "sports"),
    ("leisure", "sauna", "health"),
    
    ("tourism", "apartment", "accommodation"),
    ("tourism", "chalet", "accommodation"),
    ("tourism", "caravan_site", "accommodation"),
    ("tourism", "picnic_site", "nature"),
    ("tourism", "theme_park", "attraction"),
    ("tourism", "aquarium", "culture"),
    ("tourism", "artwork", "culture"),
    
    ("natural", "beach", "nature"),
    ("natural", "lake", "nature"),
    ("natural", "forest", "nature"),
    ("natural", "park", "nature"),
    
    ("boundary", "national_park", "nature"),
    
    ("sport", "soccer", "sports"),
    ("sport", "tennis", "sports"),
    ("sport", "basketball", "sports"),
    ("sport", "golf", "sports"),
    ("sport", "swimming", "sports"),
    ("sport", "running", "sports"),
    ("sport", "cycling", "sports"),
]
DISALLOWED_TAGS = {
    ("amenity", "bar"),
    ("amenity", "pub"),
    ("amenity", "nightclub"),
    ("amenity", "stripclub"),
    ("shop", "tobacco"),
    ("leisure", "adult_gaming_centre"),
}

DISALLOWED_KEYWORDS = [
    "alcohol",
    "smoking",
    "tobacco",
    "casino",
    "gambling",
    "hookah",
    "shisha",
    "cigar",
]


def _is_disallowed_destination(tags):
    lower_tags = {
        key.lower(): (value.lower() if isinstance(value, str) else value)
        for key, value in tags.items()
    }

    if (lower_tags.get("amenity"), lower_tags.get("bar")) in DISALLOWED_TAGS:
        return True

    if lower_tags.get("amenity") in {"bar", "pub", "nightclub", "stripclub"}:
        return True
    if lower_tags.get("shop") == "tobacco":
        return True
    if lower_tags.get("leisure") == "adult_gaming_centre":
        return True

    if lower_tags.get("smoking") in {"yes", "designated", "permitted"}:
        return True

    name = lower_tags.get("name", "")
    description = lower_tags.get("description", "")
    for keyword in DISALLOWED_KEYWORDS:
        if keyword in name or keyword in description:
            return True

    return False


def _build_long_description(
    name,
    tags,
    primary_category,
    cuisine,
    opening_hours,
    phone,
    website,
    address,
):
    description = tags.get("description", "").strip()
    if description:
        return description

    parts = []
    amenity = tags.get("amenity", "")
    tourism = tags.get("tourism", "")
    leisure = tags.get("leisure", "")

    if amenity == "restaurant":
        parts.append(
            f"{name} is a restaurant in Yaoundé known for {cuisine or 'local'} cuisine."
        )
    elif amenity == "cafe":
        parts.append(
            f"{name} is a café offering a relaxed spot for coffee and light bites."
        )
    elif amenity == "fast_food":
        parts.append(
            f"{name} is a fast-food destination popular for quick meals in Yaoundé."
        )
    elif tourism == "museum":
        parts.append(
            f"{name} is a museum offering cultural exhibits and historical insight."
        )
    elif tourism == "viewpoint":
        parts.append(
            f"{name} is a scenic viewpoint with great views over Yaoundé."
        )
    elif tourism == "hotel" or tourism == "guest_house" or tourism == "hostel":
        parts.append(
            f"{name} is a hospitality venue offering stay options for visitors."
        )
    elif leisure == "park" or leisure == "garden":
        parts.append(
            f"{name} is a green space for outdoor recreation and relaxation."
        )
    elif amenity == "library":
        parts.append(
            f"{name} is a public library serving readers and researchers."
        )
    elif amenity == "theatre" or amenity == "cinema":
        parts.append(
            f"{name} is an entertainment venue for films and performances."
        )
    elif primary_category == "culture":
        parts.append(
            f"{name} is a cultural destination with local significance in Yaoundé."
        )
    elif primary_category == "nature":
        parts.append(
            f"{name} is a nature destination offering outdoor experiences."
        )
    else:
        parts.append(f"{name} is a destination in Yaoundé, Cameroon.")

    if cuisine and amenity in {"restaurant", "cafe", "fast_food"}:
        parts.append(f"It features {cuisine} cuisine.")
    if address:
        parts.append(f"Located at {address}.")
    if opening_hours:
        parts.append(f"Opens: {opening_hours}.")
    if website:
        parts.append("Website information is available.")
    if phone:
        parts.append("Contact details are provided.")

    return " ".join(parts)


def _normalize_image_url(url: str) -> str:
    """Normalize image URLs by removing query strings and fragments and trailing slashes.
    This helps deduplicate the same image served with different query params.
    """
    if not url:
        return ""
    try:
        p = urlparse(url)
        # Keep scheme, netloc and path only; normalize scheme/netloc to lowercase
        scheme = (p.scheme or 'https').lower()
        netloc = (p.netloc or '').lower()
        cleaned = urlunparse((scheme, netloc, p.path.rstrip('/'), '', '', ''))
        return cleaned
    except Exception:
        return url.rstrip('/')

# ---------------------------------------------------------------------------
# Future-Compatible Provider Architecture
# ---------------------------------------------------------------------------

class BaseDestinationProvider:
    """Abstract base class to design compatibility with future data providers.
    Allows easy addition of Google Places, Geoapify, or Foursquare.
    """
    def get_provider_name(self) -> str:
        raise NotImplementedError

    def fetch_destinations(self) -> list:
        """Fetch and return a list of normalized destination dicts."""
        raise NotImplementedError


class OverpassProvider(BaseDestinationProvider):
    """OpenStreetMap Overpass API destination provider implementation."""
    def get_provider_name(self) -> str:
        return "openstreetmap"

    def fetch_destinations(self) -> list:
        query = _build_overpass_query()
        logger.info("Querying Overpass API for Yaoundé POIs...")

        response = requests.get(
            OVERPASS_URL,
            params={"data": query},
            timeout=45,
            headers={"User-Agent": "YaoundeGlobeTrotter/1.0"}
        )
        response.raise_for_status()
        data = response.json()

        elements = data.get("elements", [])
        logger.info(f"Overpass returned {len(elements)} elements (nodes, ways, relations)")

        normalized_list = []
        for element in elements:
            try:
                normalized = _normalize_osm_element(element)
                if normalized:
                    normalized_list.append(normalized)
            except Exception as e:
                logger.warning(f"Error normalizing element {element.get('id')}: {e}")

        return normalized_list


# ---------------------------------------------------------------------------
# Query Builder and Helpers
# ---------------------------------------------------------------------------

def _build_overpass_query():
    """Build the Overpass QL query string for Yaoundé POIs."""
    # Use nwr to query nodes, ways, and relations matching the relevant tags
    tag_filters = []
    for key, value, _ in RELEVANT_TAGS:
        if value:
            tag_filters.append(f'  nwr["{key}"="{value}"]({YAOUNDE_BBOX});')
        else:
            tag_filters.append(f'  nwr["{key}"]({YAOUNDE_BBOX});')

    tag_filters_str = "\n".join(tag_filters)

    # Use out center to compute the centroid coordinate of ways/relations
    query = f"""
[out:json][timeout:90];
(
{tag_filters_str}
);
out center;
"""
    return query.strip()


def _map_activities(tags, primary_category):
    """Map OSM tags and category into a list of activity strings."""
    activities = set()
    
    # Base activities from primary category
    if primary_category == "nature":
        activities.update(["Nature Walks", "Outdoor Recreation", "Sightseeing"])
    elif primary_category == "culture":
        activities.update(["Cultural Experience", "Historical Visit", "Sightseeing"])
    elif primary_category == "accommodation":
        activities.update(["Accommodation", "Lodging"])
    elif primary_category == "food":
        activities.update(["Dining", "Local Cuisine"])
    elif primary_category == "market":
        activities.update(["Shopping", "Local Culture"])
    elif primary_category == "sports":
        activities.update(["Sports", "Outdoor Recreation"])
    elif primary_category == "health":
        activities.update(["Health Services", "Wellness"])
    elif primary_category == "finance":
        activities.update(["Financial Services"])
    elif primary_category == "transport":
        activities.update(["Transportation"])
    elif primary_category == "services":
        activities.update(["Local Services"])
    elif primary_category == "business":
        activities.update(["Business", "Conferences", "Meetings"])

    # Refined mappings based on specific tags
    tourism = tags.get("tourism", "")
    amenity = tags.get("amenity", "")
    leisure = tags.get("leisure", "")
    historic = tags.get("historic", "")
    natural = tags.get("natural", "")
    sport = tags.get("sport", "")
    shop = tags.get("shop", "")
    boundary = tags.get("boundary", "")

    # Cultural & Historical
    if tourism == "museum" or historic:
        activities.update(["Museum Tour", "Cultural Experience", "Historical Visit"])
    if tourism == "gallery" or amenity == "arts_centre":
        activities.update(["Art Exhibition", "Cultural Experience"])
    if amenity == "theatre" or amenity == "cinema":
        activities.update(["Theatre", "Film", "Entertainment"])
    if amenity == "library":
        activities.update(["Reading", "Quiet Study", "Research"])
    if amenity == "place_of_worship":
        activities.update(["Spiritual Visit", "Architecture Tour"])
    if tourism == "monument":
        activities.update(["Historical Tour", "Photography", "Sightseeing"])
    if tourism == "artwork":
        activities.update(["Street Art Tour", "Photography"])
    if tourism == "aquarium":
        activities.update(["Marine Life Exploration", "Family Activity"])

    # Nature & Outdoors
    if tourism == "viewpoint":
        activities.update(["Sightseeing", "Photography", "Nature Walks"])
    if leisure == "park" or amenity == "park" or leisure == "garden":
        activities.update(["Picnic", "Nature Walks", "Relaxation", "Outdoor Recreation"])
    if natural == "beach" or natural == "lake":
        activities.update(["Swimming", "Relaxation", "Sunbathing", "Water Sports"])
    if natural == "forest" or boundary == "national_park" or leisure == "nature_reserve":
        activities.update(["Hiking", "Nature Walks", "Wildlife Watching", "Photography"])
    if tags.get("water") or tags.get("natural") == "water" or tags.get("waterway"):
        activities.update(["Relaxation", "Boating", "Swimming"])
    if leisure == "marina":
        activities.update(["Boating", "Sailing", "Waterfront Walk"])
    if tourism == "zoo":
        activities.update(["Wildlife Viewing", "Family Activity", "Educational Visit"])
    if leisure == "dog_park":
        activities.update(["Pet Friendly Activity", "Outdoor Recreation"])
    if leisure == "fishing":
        activities.update(["Fishing", "Relaxation"])
    if tourism == "picnic_site":
        activities.update(["Picnic", "Family Outing", "Relaxation"])
    if tourism == "theme_park":
        activities.update(["Amusement Rides", "Family Fun", "Entertainment"])

    # Food & Dining
    if amenity == "restaurant" or amenity == "cafe":
        activities.update(["Dining", "Local Cuisine"])
    if amenity == "bar" or amenity == "pub" or amenity == "nightclub":
        activities.update(["Nightlife", "Socializing", "Entertainment"])
    if amenity == "fast_food":
        activities.update(["Quick Bites", "Casual Dining"])
    if shop == "bakery":
        activities.update(["Baked Goods Tasting", "Local Food Experience"])

    # Accommodation
    if tourism in ["hotel", "guest_house", "hostel", "motel", "apartment", "chalet"]:
        activities.update(["Accommodation", "Lodging"])
    if amenity == "restaurant":
        # If hotel, also add dining
        activities.update(["On-site Dining"])

    # Sports
    if leisure == "stadium" or leisure == "sports_centre":
        activities.update(["Sports Events", "Outdoor Recreation"])
    if sport == "swimming" or leisure == "swimming_pool" or amenity == "swimming_pool":
        activities.update(["Swimming", "Relaxation"])
    if sport == "soccer":
        activities.update(["Football", "Sports Viewing"])
    if sport == "tennis":
        activities.update(["Tennis"])
    if sport == "basketball":
        activities.update(["Basketball"])
    if sport == "golf":
        activities.update(["Golf"])
    if sport == "running":
        activities.update(["Running", "Jogging"])
    if sport == "cycling":
        activities.update(["Cycling", "Bike Riding"])
    if leisure == "ice_rink":
        activities.update(["Ice Skating"])
    if leisure == "miniature_golf":
        activities.update(["Mini Golf", "Family Activity"])
    if leisure == "fitness_centre":
        activities.update(["Fitness Training", "Workout"])
    if leisure == "sauna":
        activities.update(["Sauna", "Wellness", "Relaxation"])

    # Shopping
    if shop in ["mall", "department_store", "supermarket", "convenience"]:
        activities.update(["Shopping", "Retail Therapy"])
    if amenity == "marketplace":
        activities.update(["Local Market Experience", "Shopping"])

    # Health & Services
    if amenity in ["pharmacy", "hospital", "clinic"]:
        activities.update(["Health Services", "Medical Care"])
    if amenity in ["bank", "bureau_de_change"]:
        activities.update(["Financial Services", "Currency Exchange"])
    if amenity == "post_office":
        activities.update(["Postal Services"])
    if amenity in ["taxi", "bus_station", "ferry_terminal"]:
        activities.update(["Public Transport", "Travel Hub"])

    # Business
    if amenity == "conference_centre" or amenity == "events_venue":
        activities.update(["Conferences", "Corporate Events", "Meetings"])
    if amenity == "community_centre":
        activities.update(["Community Events", "Workshops"])

    return list(activities)


def _detect_facilities(tags):
    """Detect and return a list of standard facilities/amenities based on OSM tags."""
    facilities = set()
    
    # 1. Parking
    if tags.get("parking") or tags.get("amenity") == "parking" or tags.get("parking:geometry"):
        facilities.add("Parking")
        
    # 2. Wheelchair Accessibility
    wheelchair = tags.get("wheelchair", "")
    if wheelchair in ["yes", "designated", "limited"]:
        facilities.add("Wheelchair Accessible")
        
    # 3. Free Wi-Fi
    wifi = tags.get("wifi", "")
    internet = tags.get("internet_access", "")
    if wifi == "free" or internet in ["yes", "wlan", "wifi"] or tags.get("internet_access:fee") == "no":
        facilities.add("Free Wi-Fi")
        
    # 4. Restrooms
    if tags.get("toilets") == "yes" or tags.get("toilets:disposal") or tags.get("amenity") == "toilets":
        facilities.add("Restrooms")
        
    # 5. Children's Play Area
    if tags.get("playground") or tags.get("leisure") == "playground":
        facilities.add("Children's Play Area")
        
    # 6. Air Conditioning
    if tags.get("air_conditioning") == "yes" or tags.get("drinking_water:cooler") == "yes":
        facilities.add("Air Conditioning")
        
    # 7. Swimming Pool
    if tags.get("sport") == "swimming" or tags.get("leisure") == "swimming_pool" or tags.get("swimming_pool") == "yes":
        facilities.add("Swimming Pool")
        
    # 8. Gym
    if tags.get("leisure") == "sports_centre" or tags.get("sport") == "fitness" or tags.get("gym") == "yes":
        facilities.add("Gym")
        
    # 9. Prayer Room
    if tags.get("amenity") == "place_of_worship" or tags.get("room") == "prayer" or tags.get("amenity") == "prayer_room":
        facilities.add("Prayer Room")
        
    # 10. ATM
    if tags.get("amenity") == "atm" or tags.get("atm") == "yes":
        facilities.add("ATM")
        
    # 11. EV Charging
    if tags.get("amenity") == "charging_station" or tags.get("fuel:electricity") == "yes":
        facilities.add("EV Charging")
        
    # 12. Pet Friendly
    if tags.get("pets") == "yes" or tags.get("dog") == "yes":
        facilities.add("Pet Friendly")
        
    # 13. Security / Surveillance
    if tags.get("security") == "yes" or tags.get("security:camera") == "yes":
        facilities.add("Security")
        
    # 14. Outdoor Seating
    if tags.get("outdoor_seating") == "yes" or tags.get("outdoor_seating:terrace") == "yes":
        facilities.add("Outdoor Seating")
        
    # 15. Luggage Storage
    if tags.get("luggage_storage") == "yes" or tags.get("luggage_locker") == "yes":
        facilities.add("Luggage Storage")
        
# (Removed: Smoking Area — not appropriate for a travel destination app)
        
    # 17. Breakfast
    if tags.get("breakfast") == "yes" or tags.get("breakfast") == "buffet":
        facilities.add("Breakfast Available")
        
    # 18. Bar / On-site Bar
    if tags.get("amenity") == "bar" or tags.get("mineral_water") == "yes":
        facilities.add("On-site Bar")
        
    # 19. Baby Changing Facilities
    if tags.get("changing_table") == "yes" or tags.get("baby") == "yes":
        facilities.add("Baby Changing Facilities")
        
    # 20. Shower
    if tags.get("shower") == "yes":
        facilities.add("Shower Facilities")
        
    # 21. Drinking Water
    if tags.get("drinking_water") == "yes":
        facilities.add("Drinking Water")
        
    # 22. Camping / Caravan Facilities
    if tags.get("tourism") == "camp_site" or tags.get("tourism") == "caravan_site":
        facilities.add("Camping Facilities")
        
    # 23. Elevator / Lift
    if tags.get("elevator") == "yes" or tags.get("lift") == "yes":
        facilities.add("Elevator")
        
    # 24. Generator / Power Backup
    if tags.get("generator") == "yes" or tags.get("backup_generator") == "yes":
        facilities.add("Power Backup")
        
    return list(facilities)


def _normalize_osm_element(element):
    """Convert an OSM element dict into our destination shape.

    Returns None if the element can't be normalized (no name).
    """
    tags = element.get("tags", {})
    osm_id = f"{element['type']}/{element['id']}"
    name = tags.get("name", "").strip()

    if not name:
        return None  # Skip unnamed elements

    if _is_disallowed_destination(tags):
        return None

    # Determine primary tag/category
    primary_category = "attraction"
    for key, value, category in RELEVANT_TAGS:
        if value:
            if tags.get(key) == value:
                primary_category = category
                break
        else:
            if key in tags:
                primary_category = category
                break

    # Build category tags list
    tag_set = set()
    tag_set.add(primary_category)
    for key, value, category in RELEVANT_TAGS:
        if value:
            if tags.get(key) == value:
                tag_set.add(category)
        else:
            if key in tags:
                tag_set.add(category)
    normalized_tags = list(tag_set)

    # 1. Latitude & Longitude (center is provided for ways/relations)
    lat = element.get("lat") or element.get("center", {}).get("lat")
    lon = element.get("lon") or element.get("center", {}).get("lon")

    # 2. Formatted full address
    addr_parts = []
    h_num = tags.get("addr:housenumber")
    street = tags.get("addr:street")
    suburb = tags.get("addr:suburb")
    city = tags.get("addr:city", "Yaoundé")
    if h_num and street:
        addr_parts.append(f"{h_num} {street}")
    elif street:
        addr_parts.append(street)
    if suburb:
        addr_parts.append(suburb)
    addr_parts.append(city)
    address = ", ".join(addr_parts)

    area = f"{suburb}, Yaoundé" if suburb else city

    # 3. Contact details
    phone = tags.get("phone") or tags.get("contact:phone") or ""
    website = tags.get("website") or tags.get("contact:website") or tags.get("url") or ""
    email = tags.get("email") or tags.get("contact:email") or ""

    # 4. Opening Hours
    opening_hours = tags.get("opening_hours") or ""

    # 5. Cuisine
    cuisine = tags.get("cuisine") or ""

    # 6. Star Rating (stars tag parsed as float if present)
    star_rating = None
    stars_tag = tags.get("stars")
    if stars_tag:
        try:
            clean_stars = ''.join(c for c in stars_tag if c.isdigit() or c == '.')
            if clean_stars:
                star_rating = float(clean_stars)
        except ValueError:
            pass

    # 7. Price Level (payment or pricing tags)
    price_level = None
    if tags.get("price_level"):
        try:
            price_level = int(tags["price_level"])
        except ValueError:
            pass
    if price_level is None:
        # Estimate price level from other tags (1 to 4 scale)
        if tags.get("amenity") == "fast_food":
            price_level = 1
        elif tags.get("amenity") == "restaurant":
            price_level = 2
        elif tags.get("tourism") == "hotel":
            price_level = 3
        elif tags.get("amenity") == "nightclub" or tags.get("amenity") == "bar":
            price_level = 2

    # 8. Description from tags
    description = _build_long_description(
        name,
        tags,
        primary_category,
        cuisine,
        opening_hours,
        phone,
        website,
        address,
    )

    # 9. Activities & Experiences mapping
    activities = _map_activities(tags, primary_category)

    # 10. Facilities detection
    facilities = _detect_facilities(tags)

    # 11. Images fetching (supporting gallery) — max 6 diverse images per destination
    MAX_IMAGES = 6
    wikidata_id = tags.get("wikidata", "")
    wikipedia = tags.get("wikipedia", "")
    osm_image = tags.get("image") or tags.get("contact:image") or ""
    
    image_list = []
    image_source = "placeholder"

    # Track seen URLs for deduplication
    seen_urls = set()

    if osm_image and len(image_list) < MAX_IMAGES:
        normalized_url = _normalize_image_url(osm_image)
        if normalized_url and normalized_url not in seen_urls:
            image_list.append(normalized_url)
            seen_urls.add(normalized_url)
            image_source = "osm"

    if (wikidata_id or wikipedia) and len(image_list) < MAX_IMAGES:
        fetched_images, verified = fetch_wikimedia_image(
            wikidata_id=wikidata_id,
            wikipedia_title=wikipedia,
            place_name=name
        )
        if fetched_images and verified:
            for img in fetched_images:
                if len(image_list) >= MAX_IMAGES:
                    break
                normalized_url = _normalize_image_url(img)
                if normalized_url and normalized_url not in seen_urls:
                    image_list.append(normalized_url)
                    seen_urls.add(normalized_url)
            if image_list:
                image_source = "wikimedia"

    # Fallback to placeholder if no images found (max 1 placeholder)
    if not image_list:
        placeholder_img = _normalize_image_url(get_placeholder_image(primary_category, name))
        image_list.append(placeholder_img)
        image_source = "placeholder"

    # Main image (backward compatibility)
    main_image = image_list[0] if image_list else ""

    return {
        "osm_id": osm_id,
        "name": name,
        "area": area,
        "tags": normalized_tags,
        "description": description,
        "long_description": description,
        "cost": price_level * 10000 if price_level else None,  # Cost in XAF
        "image": main_image,
        "image_source": image_source,
        "latitude": lat,
        "longitude": lon,
        "address": address,
        "category": primary_category,
        "activities": activities,
        "opening_hours": opening_hours,
        "phone": phone,
        "website": website,
        "email": email,
        "price_level": price_level,
        "facilities": facilities,
        "cuisine": cuisine,
        "star_rating": star_rating,
        "images": image_list
    }


# ---------------------------------------------------------------------------
# Deduplication and Database Synchronization
# ---------------------------------------------------------------------------

def deduplicate_and_sync(incoming_list, app=None):
    """Filter out duplicate destinations, keeping the one with richer information.
    Ensures ratings of updated destinations are preserved by updating the existing database row.
    """
    from app.models import get_connection, get_all_destinations, upsert_destination

    # 1. Deduplicate the incoming list among itself
    unique_incoming = {}

    def get_completeness_score(d):
        score = 0
        if d.get("image") and "placeholder" not in d.get("image_source", ""): score += 1
        if d.get("address"): score += 1
        if d.get("description") and "A " not in d["description"]: score += 1
        if d.get("opening_hours"): score += 1
        if d.get("phone"): score += 1
        if d.get("website"): score += 1
        if d.get("email"): score += 1
        if d.get("price_level"): score += 1
        if d.get("cuisine"): score += 1
        if d.get("star_rating"): score += 1
        if len(d.get("facilities", [])) > 0: score += 1
        if len(d.get("activities", [])) > 0: score += 1
        if len(d.get("images", [])) > 1: score += 1
        return score

    # Group incoming items by name (lowercase)
    name_groups = {}
    for item in incoming_list:
        name_key = item["name"].lower().strip()
        name_groups.setdefault(name_key, []).append(item)

    final_incoming = []
    discarded_osm_ids = []

    for name_key, items in name_groups.items():
        # Within each name group, deduplicate based on distance (~300m = 0.0027 degrees)
        resolved = []
        for item in items:
            lat1 = item["latitude"]
            lon1 = item["longitude"]

            if lat1 is None or lon1 is None:
                final_incoming.append(item)
                continue

            duplicate_found = False
            for r_idx, r_item in enumerate(resolved):
                lat2 = r_item["latitude"]
                lon2 = r_item["longitude"]

                dist = ((lat1 - lat2)**2 + (lon1 - lon2)**2)**0.5
                if dist < 0.0027:
                    duplicate_found = True
                    # Compare completeness score
                    score_new = get_completeness_score(item)
                    score_existing = get_completeness_score(r_item)
                    if score_new > score_existing:
                        # Keep richer one, discard poorer one
                        discarded_osm_ids.append(r_item["osm_id"])
                        resolved[r_idx] = item
                    else:
                        discarded_osm_ids.append(item["osm_id"])
                    break
            if not duplicate_found:
                resolved.append(item)
        final_incoming.extend(resolved)

    # 2. Group existing database records by name and check distance
    conn = get_connection(app)
    existing_destinations = conn.execute("SELECT id, osm_id, name, latitude, longitude FROM destinations").fetchall()
    existing_map = {d["osm_id"]: d for d in existing_destinations}

    db_updates = []

    for item in final_incoming:
        lat1 = item["latitude"]
        lon1 = item["longitude"]
        osm_id = item["osm_id"]

        # If exact OSM ID already exists, we will just upsert it natively
        if osm_id in existing_map:
            continue

        # Check for matching name/distance in DB under a different OSM ID (e.g. node vs way duplicate)
        db_duplicate = None
        for db_dest in existing_destinations:
            if db_dest["name"].lower().strip() == item["name"].lower().strip():
                lat2 = db_dest["latitude"]
                lon2 = db_dest["longitude"]
                if lat1 is not None and lon1 is not None and lat2 is not None and lon2 is not None:
                    dist = ((lat1 - lat2)**2 + (lon1 - lon2)**2)**0.5
                    if dist < 0.0027:
                        db_duplicate = db_dest
                        break

        if db_duplicate:
            # Duplicate found in DB under a different OSM ID! Check completeness to see if we replace it
            db_full = conn.execute("SELECT * FROM destinations WHERE id = ?", (db_duplicate["id"],)).fetchone()
            db_full_dict = dict(db_full)
            for k in ["tags", "activities", "facilities", "images"]:
                if k in db_full_dict and isinstance(db_full_dict[k], str):
                    try:
                        db_full_dict[k] = json.loads(db_full_dict[k])
                    except:
                        db_full_dict[k] = []

            score_db = get_completeness_score(db_full_dict)
            score_incoming = get_completeness_score(item)

            if score_incoming > score_db:
                # The incoming one is richer! Update the existing DB row to point to new osm_id and values
                # This preserves the UUID "id" of the record so user ratings are NOT lost!
                logger.info(f"Replacing duplicate DB entry {db_duplicate['osm_id']} with richer incoming {osm_id}")
                db_updates.append((db_duplicate["id"], item))
                discarded_osm_ids.append(db_duplicate["osm_id"])
            else:
                # DB entry is richer! Discard the incoming duplicate.
                logger.info(f"Discarding duplicate incoming {osm_id} in favor of richer DB entry {db_duplicate['osm_id']}")
                discarded_osm_ids.append(osm_id)

    conn.close()

    # Now write new unique ones to DB
    count = 0
    for item in final_incoming:
        if item["osm_id"] in discarded_osm_ids:
            continue

        upsert_destination(
            osm_id=item["osm_id"],
            name=item["name"],
            area=item["area"],
            tags=item["tags"],
            description=item["description"],
            long_description=item.get("long_description", item.get("description", "")),
            cost=item["cost"],
            image=item["image"],
            image_source=item["image_source"],
            latitude=item["latitude"],
            longitude=item["longitude"],
            address=item["address"],
            category=item["category"],
            activities=item["activities"],
            opening_hours=item["opening_hours"],
            phone=item["phone"],
            website=item["website"],
            email=item["email"],
            price_level=item["price_level"],
            facilities=item["facilities"],
            cuisine=item["cuisine"],
            star_rating=item["star_rating"],
            images=item["images"],
            app=app
        )
        count += 1

    # Perform updates for richer duplicate matches (reusing database ID)
    if db_updates:
        conn = get_connection(app)
        for dest_id, item in db_updates:
            now = datetime.datetime.now(datetime.timezone.utc).isoformat()
            conn.execute("""
                UPDATE destinations SET
                    osm_id = ?, name = ?, area = ?, tags = ?, description = ?,
                    long_description = ?, cost = ?, image = ?, image_source = ?, last_synced_at = ?,
                    latitude = ?, longitude = ?, address = ?, category = ?,
                    activities = ?, opening_hours = ?, phone = ?, website = ?,
                    email = ?, price_level = ?, facilities = ?, cuisine = ?,
                    star_rating = ?, images = ?
                WHERE id = ?
            """, (
                item["osm_id"], item["name"], item["area"], json.dumps(item["tags"]), item["description"],
                item.get("long_description", item.get("description", "")), item["cost"], item["image"], item["image_source"], now,
                item["latitude"], item["longitude"], item["address"], item["category"],
                json.dumps(item["activities"]), item["opening_hours"], item["phone"], item["website"],
                item["email"], item["price_level"], json.dumps(item["facilities"]), item["cuisine"],
                item["star_rating"], json.dumps(item["images"]), dest_id
            ))
            count += 1
        conn.commit()
        conn.close()

    # Clean up duplicate rows in DB if they match discarded ones
    if discarded_osm_ids:
        conn = get_connection(app)
        for d_id in discarded_osm_ids:
            conn.execute("DELETE FROM destinations WHERE osm_id = ?", (d_id,))
        conn.commit()
        conn.close()

    return count


def sync_destinations(app=None):
    """Fetch destinations from Overpass API and store in database (with deduplication).

    Returns the count of new/updated destinations on success.
    Handles Overpass being slow or unavailable gracefully by returning cached data.
    """
    from app.models import get_all_destinations, set_last_synced_now

    # Use Overpass Provider
    provider = OverpassProvider()
    
    try:
        incoming_destinations = provider.fetch_destinations()
    except Exception as e:
        logger.warning(f"Overpass API request failed: {e}")
        # Return cached data count
        cached = get_all_destinations(app)
        logger.info(f"Returning {len(cached)} cached destinations")
        return len(cached) if cached else 0

    count = deduplicate_and_sync(incoming_destinations, app)
    set_last_synced_now(app)
    logger.info(f"Synchronized {count} destinations from Overpass")
    return count


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
                    count = sync_destinations(app)
                    logger.info(f"Periodic background destination sync completed: {count} destinations.")
            except Exception as e:
                logger.error(f"Periodic background destination sync failed: {e}", exc_info=True)

    thread = threading.Thread(target=run_sync_loop, daemon=True)
    thread.start()
