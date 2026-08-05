"""recommendation-service/overpass_sync.py

OpenStreetMap Overpass API integration for Yaoundé, Cameroon.
Fetches real destinations (nodes, ways, and relations), normalizes them,
deduplicates them, and stores them in SQLite.
Supports periodic background synchronization.
"""
import json
import logging
import re
import time
import datetime
import requests
import threading
from app.image_utils import (
    fetch_wikimedia_image,
    get_placeholder_image,
    get_placeholder_pool,
)
from urllib.parse import urlparse

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


def _has_junk_description(text):
    """Detect unusable / non-descriptive raw OSM description strings.

    Examples of junk we reject:
        "#GGK Diocèse d'Obala", "no description", "n/a", "???", "null",
        "opening hours", "horaire", etc.
    """
    if not text:
        return True
    cleaned = text.strip()
    if len(cleaned) < 10:
        return True
    lower = cleaned.lower()
    if "#" in cleaned:  # hashtags / social metadata are not descriptions
        return True
    if lower.startswith(("no ", "none", "n/a", "na ", "null", "unknown", "???")):
        return True
    if lower in {"opening hours", "horaire", "horaire :", "open", "closed"}:
        return True
    return False


def _safe_description(text):
    """Return a usable description or empty string, stripping junk."""
    if _has_junk_description(text):
        return ""
    return text.strip()


# Generic / non-destination names that should never be shown to travellers.
_JUNK_NAME_PATTERNS = [
    "bench",
    "bus stop",
    "stop",
    "parking",
    "wc",
    "toilet",
    "roundabout",
    "traffic",
    "signal",
    "hydrant",
    "manhole",
    "street lamp",
    "address point",
    "entrance",
    "gate",
    "fence",
    "wall",
    "bollard",
    "bench 1",
    "bench 2",
    "poi",
    "fixme",
    "no name",
    "unnamed",
]


def _has_junk_name(name):
    """Reject names that don't represent a real travel destination."""
    if not name:
        return True
    lower = name.lower().strip()
    if len(lower) < 3:
        return True
    # Pure generic labels like "Restaurant", "Pharmacy", "Hotel" without a
    # distinctive part are not useful to travellers.
    generic_nouns = {
        "restaurant", "cafe", "hotel", "bar", "shop", "supermarket",
        "pharmacy", "hospital", "church", "school", "market",
        "fast food", "fast-food", "bakery", "hôtel", "mosquée",
        "église", "clinique", "marché", "parking", "bureau",
    }
    if lower in generic_nouns or lower.rstrip(" .") in generic_nouns:
        return True
    for pattern in _JUNK_NAME_PATTERNS:
        if pattern in lower:
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
    description = _safe_description(tags.get("description", ""))
    parts = []

    amenity = tags.get("amenity", "")
    tourism = tags.get("tourism", "")
    leisure = tags.get("leisure", "")
    historic = tags.get("historic", "")
    natural = tags.get("natural", "")
    shop = tags.get("shop", "")
    sport = tags.get("sport", "")

    # First sentence: what the place is.
    if amenity == "restaurant":
        parts.append(
            f"{name} is a restaurant in Yaoundé known for {cuisine or 'local'} cuisine, "
            f"offering a genuine taste of {cuisine or 'Cameroonian'} flavours."
        )
    elif amenity == "cafe":
        parts.append(
            f"{name} is a café in Yaoundé offering a relaxed spot for coffee, "
            f"snacks and light bites."
        )
    elif amenity == "fast_food":
        parts.append(
            f"{name} is a fast-food spot in Yaoundé popular for quick, "
            f"affordable meals on the go."
        )
    elif tourism == "museum":
        parts.append(
            f"{name} is a museum in Yaoundé where visitors can explore "
            f"cultural exhibits, historical artefacts and local heritage."
        )
    elif tourism == "viewpoint":
        parts.append(
            f"{name} is a scenic viewpoint in Yaoundé offering panoramic views "
            f"over the city and its green hills."
        )
    elif tourism in {"hotel", "guest_house", "hostel", "motel", "apartment", "chalet"}:
        parts.append(
            f"{name} is a hospitality venue in Yaoundé offering comfortable "
            f"stay options for visitors."
        )
    elif leisure in {"park", "garden"} or amenity == "park":
        parts.append(
            f"{name} is a green space in Yaoundé, ideal for outdoor recreation, "
            f"relaxation and family outings."
        )
    elif leisure == "nature_reserve" or natural == "forest" or tags.get("boundary") == "national_park":
        parts.append(
            f"{name} is a natural reserve in the Yaoundé area, rich in "
            f"biodiversity and perfect for hiking and wildlife watching."
        )
    elif tourism == "zoo":
        parts.append(
            f"{name} is a zoo in the Yaoundé area where visitors can observe "
            f"local and exotic wildlife in a family-friendly setting."
        )
    elif historic:
        parts.append(
            f"{name} is a historic site in Yaoundé with significant cultural "
            f"and architectural value."
        )
    elif amenity == "library":
        parts.append(
            f"{name} is a public library in Yaoundé serving readers, students "
            f"and researchers."
        )
    elif amenity in {"theatre", "cinema"}:
        parts.append(
            f"{name} is an entertainment venue in Yaoundé hosting films, "
            f"performances and cultural events."
        )
    elif amenity == "marketplace" or shop in {"mall", "department_store", "supermarket"}:
        parts.append(
            f"{name} is a lively shopping destination in Yaoundé where visitors "
            f"can experience local commerce and daily life."
        )
    elif amenity == "place_of_worship":
        parts.append(
            f"{name} is a place of worship in Yaoundé, notable for its "
            f"architecture and spiritual significance."
        )
    elif amenity in {"pharmacy", "hospital", "clinic"}:
        parts.append(
            f"{name} is a healthcare facility in Yaoundé providing essential "
            f"medical services to residents and visitors."
        )
    elif amenity in {"bank", "bureau_de_change"}:
        parts.append(
            f"{name} is a financial services point in Yaoundé, useful for "
            f"banking and currency exchange needs."
        )
    elif sport:
        parts.append(
            f"{name} is a sports destination in Yaoundé offering facilities "
            f"for {sport} and active recreation."
        )
    elif primary_category == "culture":
        parts.append(
            f"{name} is a cultural destination in Yaoundé with local "
            f"significance and visitor interest."
        )
    elif primary_category == "nature":
        parts.append(
            f"{name} is a nature destination around Yaoundé offering outdoor "
            f"experiences and scenic surroundings."
        )
    else:
        parts.append(f"{name} is a destination in Yaoundé, Cameroon.")

    # Second sentence: practical visitor information.
    info = []
    if cuisine and amenity in {"restaurant", "cafe", "fast_food"}:
        info.append(f"The venue specialises in {cuisine} cuisine")
    if address:
        info.append(f"It is located at {address}")
    if opening_hours:
        info.append(f"typical opening hours are {opening_hours}")
    if phone:
        info.append("phone contact is available for enquiries")
    if website:
        info.append("further details can be found on its website")

    if info:
        sentence = ", and ".join(info) + "."
        parts.append(sentence.capitalize())

    # Third sentence: recommendation/context.
    if description:
        parts.append(description)

    if primary_category == "nature":
        parts.append(
            "It is a great stop for travellers who enjoy the outdoors and photography."
        )
    elif primary_category in {"culture", "attraction"}:
        parts.append(
            "It is a worthwhile stop for travellers interested in the culture and history of Yaoundé."
        )
    elif primary_category == "food":
        parts.append(
            "It is a good option for travellers who want to experience the local food scene."
        )
    elif primary_category == "accommodation":
        parts.append(
            "It is a convenient base for exploring the rest of Yaoundé."
        )

    return " ".join(parts)


def _normalize_image_url(url: str) -> str:
    """Normalize image URLs to a canonical form for robust deduplication.

    Rules applied (in order):
    - Enforces HTTPS (http://foo -> https://foo, so http and https are the same)
    - Removes 'www.' prefix from the host
    - Lowercases scheme and host
    - Removes query strings ('?...') and fragments ('#...')
    - Removes trailing slashes
    - For Wikimedia Commons, removes thumbnail paths to get the original image URL.
      e.g. /thumb/c/c3/img.jpg/100px-img.jpg -> /c/c3/img.jpg
    - Canonicalizes percent-encoding: decodes then re-encodes with uppercase hex
      so %c3%a9 == %C3%A9, and treats encoded vs literal special characters the same.
    """
    if not url:
        return ""
    try:
        p = urlparse(url)

        # 1) Force HTTPS scheme. http and https are treated as identical for
        # dedup purposes (the same photo is served over both).
        scheme = "https"

        # 2) Normalize netloc: lowercase, strip userinfo, strip port, strip www.
        netloc = (p.netloc or "").lower()
        if "@" in netloc:
            netloc = netloc.rsplit("@", 1)[-1]
        if netloc.startswith("www."):
            netloc = netloc[4:]
        # Drop the port if it's a default 80/443 on http/https.
        if netloc.endswith(":80") and scheme == "http":
            netloc = netloc[:-3]
        elif netloc.endswith(":443") and scheme == "https":
            netloc = netloc[:-4]

        # 3) Normalize path.
        path = p.path

        # Special handling for Wikimedia Commons thumbnails:
        # /thumb/<a>/<ab>/<File>/<NNNpx-<File>> -> /<a>/<ab>/<File>
        if "upload.wikimedia.org" in netloc:
            path = re.sub(r'/thumb/(.+?)/[^/]+$', r'/\1', path)

        # 4) Canonicalize percent-encoding: unquote then quote.
        from urllib.parse import unquote, quote
        unquoted = unquote(path)
        # Never re-encode '/' separators or ':' (keep path structure).
        canonical_path = quote(unquoted, safe="/:,. _-()'")

        # 5) Strip trailing slashes (after canonicalization).
        canonical_path = canonical_path.rstrip("/")

        # 6) Drop query string and fragment entirely.
        return f"{scheme}://{netloc}{canonical_path}"

    except Exception as e:
        logger.warning(f"URL normalization failed for '{url}': {e}")
        # Fallback for malformed URLs
        return url.strip().lower().rstrip("/")

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

    if _has_junk_name(name):
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
    
    # Step 1: Collect all potential URLs from all sources
    potential_urls = []
    osm_image_val = tags.get("image") or tags.get("contact:image") or ""
    if osm_image_val:
        potential_urls.append(osm_image_val)

    # Step 2: Fetch from Wikimedia if applicable
    wikimedia_urls, wikimedia_verified = [], False
    if (wikidata_id or wikipedia):
        wikimedia_urls, wikimedia_verified = fetch_wikimedia_image(
            wikidata_id=wikidata_id,
            wikipedia_title=wikipedia,
            place_name=name
        )
        if wikimedia_urls:
            potential_urls.extend(wikimedia_urls)

    # Step 3: Normalize and deduplicate
    image_list = []
    seen_urls = set()
    for url in potential_urls:
        if len(image_list) >= MAX_IMAGES:
            break
        normalized_url = _normalize_image_url(url)
        if normalized_url and normalized_url not in seen_urls:
            image_list.append(normalized_url)
            seen_urls.add(normalized_url)

    # Step 4: Determine image source and apply placeholder if needed.
    image_source = "placeholder"
    if image_list:
        if wikimedia_urls:
            image_source = "wikimedia"
        elif osm_image_val:
            image_source = "osm"
    else:
        # No real image found — assign a deterministic placeholder now so the
        # gallery is never empty. The global re-diversity pass in
        # _minimize_placeholder_reuse() will still spread these out across the pool.
        fallback_url = get_placeholder_image(primary_category, name)
        if fallback_url:
            image_list = [_normalize_image_url(fallback_url)]

    # Main image (for legacy API compatibility) is the first in the list.
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
        "images": image_list  # The full, deduplicated list
    }


# ---------------------------------------------------------------------------
# Deduplication and Database Synchronization
# ---------------------------------------------------------------------------

def _minimize_placeholder_reuse(items, used_real_images):
    """Assign placeholder images with STRICT GLOBAL UNIQUENESS.

    This function is called after real images have been deduplicated. It enforces
    the hard rule that NO image URL may appear more than once across the entire
    dataset — this includes placeholder images.

    It handles two types of items:
    1. Items that were originally placeholders.
    2. Items that had real images, but all were duplicates and were removed.

    For each such destination, it assigns the *least-used* placeholder from the
    appropriate category pool, but ONLY if that image has not already been used
    anywhere (real or placeholder). If every image in the pool is already taken,
    the destination is left with NO image (empty list and empty main image) rather
    than reusing an existing one. This is intentional: per the product requirement,
    it is better for a destination to have no image than to show a duplicate.
    """
    # Track every image URL already assigned globally (real images + placeholders).
    # Start with the real images that were kept.
    used_globally = set(used_real_images)
    if isinstance(used_globally, (list, tuple)):
        used_globally = {_normalize_image_url(u) for u in used_globally}

    # Build the full, ordered list of all placeholder pool URLs (deduplicated).
    category_keys = [
        "food", "nature", "culture", "market", "accommodation",
        "sports", "attraction", "general",
    ]
    all_placeholder_images = []
    seen_pool = set()
    for category in category_keys:
        for image in get_placeholder_pool(category):
            n = _normalize_image_url(image)
            if n and n not in seen_pool:
                seen_pool.add(n)
                all_placeholder_images.append(n)

    # Track global usage count per placeholder image (for even distribution).
    placeholder_usage = {n: 0 for n in all_placeholder_images}

    for item in items:
        if item.get("image_source") != "placeholder":
            continue

        category = item.get("category", "general")
        pool = get_placeholder_pool(category)
        if not pool:
            continue

        # Candidate images for this category + general fallback, in order.
        candidate_urls = []
        for p in pool:
            n = _normalize_image_url(p)
            if n and n not in used_globally:
                candidate_urls.append(n)
        if not candidate_urls:
            for p in get_placeholder_pool("general"):
                n = _normalize_image_url(p)
                if n and n not in used_globally:
                    candidate_urls.append(n)

        if not candidate_urls:
            # No unused image available anywhere — leave the destination with NO
            # image rather than duplicate an existing one.
            item["images"] = []
            item["image"] = ""
            item["image_source"] = "placeholder"
            continue

        # Pick the least-used candidate (deterministic tie-break by URL).
        best_choice = min(candidate_urls, key=lambda u: (placeholder_usage.get(u, 0), u))

        item["images"] = [best_choice]
        item["image"] = best_choice
        item["image_source"] = "placeholder"

        # Mark this image as used globally so it can never be assigned twice.
        used_globally.add(best_choice)
        placeholder_usage[best_choice] = placeholder_usage.get(best_choice, 0) + 1

def _deduplicate_real_images(items):
    """
    Ensures that a real image URL is used for at most one destination.
    If a destination's images are all removed, it's marked as a placeholder.
    Returns the set of all real image URLs that were used.
    """
    used_real_images = set()
    for item in sorted(items, key=lambda x: get_completeness_score(x), reverse=True):
        if item.get("image_source") in ("osm", "wikimedia"):
            unique_images_for_item = []
            original_images = item.get("images", [])
            
            for img_url in original_images:
                normalized = _normalize_image_url(img_url)
                if normalized not in used_real_images:
                    unique_images_for_item.append(img_url)
                    used_real_images.add(normalized)
            
            item["images"] = unique_images_for_item
            
            # If all images were duplicates, this destination becomes a placeholder
            if not item["images"]:
                item["image_source"] = "placeholder"
                item["image"] = "" # Will be filled in by _minimize_placeholder_reuse
            else:
                item["image"] = item["images"][0]
    return used_real_images

def deduplicate_and_sync(incoming_list, app=None):
    """Filter out duplicate destinations, keeping the one with richer information.
    Ensures ratings of updated destinations are preserved by updating the existing database row.
    """
    from app.models import get_connection, get_all_destinations, upsert_destination

    def get_completeness_score(d):
        score = 0
        if not d: return 0
        if d.get("image") and d.get("image_source") != "placeholder": score += 5
        if d.get("long_description") and len(d.get("long_description", "")) > 100: score += 3
        if d.get("address"): score += 2
        if d.get("website"): score += 1
        if d.get("phone"): score += 1
        if d.get("opening_hours"): score += 1
        score += len(d.get("facilities", [])) / 5.0
        return score

    # 1. Deduplicate the incoming list based on name and location proximity
    name_groups = {}
    for item in incoming_list:
        name_key = item["name"].lower().strip()
        name_groups.setdefault(name_key, []).append(item)

    final_incoming = []
    for name_key, items in name_groups.items():
        # Sort by completeness to process richer items first
        sorted_items = sorted(items, key=lambda x: get_completeness_score(x), reverse=True)
        resolved = []
        for item in sorted_items:
            lat1 = item.get("latitude")
            lon1 = item.get("longitude")
            if lat1 is None or lon1 is None:
                if not any(r["name"].lower().strip() == item["name"].lower().strip() for r in resolved):
                    resolved.append(item)
                continue

            is_duplicate = False
            for r_item in resolved:
                lat2 = r_item.get("latitude")
                lon2 = r_item.get("longitude")
                if lat2 is None or lon2 is None:
                    continue
                
                # Check for proximity (approx 300m)
                dist = ((lat1 - lat2)**2 + (lon1 - lon2)**2)**0.5
                if dist < 0.0027:
                    is_duplicate = True
                    break
            if not is_duplicate:
                resolved.append(item)
        final_incoming.extend(resolved)

    # 2. Compare with existing DB entries to decide on updates vs. inserts
    conn = get_connection(app)
    existing_destinations = conn.execute("SELECT id, osm_id, name, latitude, longitude FROM destinations").fetchall()
    existing_map_by_name = {}
    for d in existing_destinations:
        existing_map_by_name.setdefault(d["name"].lower().strip(), []).append(d)

    db_updates = []
    items_to_insert = []
    
    # Sort by completeness score descending to give richer items priority for image claims
    final_incoming.sort(key=get_completeness_score, reverse=True)

    for item in final_incoming:
        name_key = item["name"].lower().strip()
        db_duplicates = existing_map_by_name.get(name_key, [])
        
        is_update_of = None
        if db_duplicates:
            lat1 = item.get("latitude")
            lon1 = item.get("longitude")
            if lat1 is not None and lon1 is not None:
                for db_dest in db_duplicates:
                    lat2 = db_dest.get("latitude")
                    lon2 = db_dest.get("longitude")
                    if lat2 is not None and lon2 is not None:
                        dist = ((lat1 - lat2)**2 + (lon1 - lon2)**2)**0.5
                        if dist < 0.0027:
                            is_update_of = db_dest
                            break
        
        if is_update_of:
            db_full = conn.execute("SELECT * FROM destinations WHERE id = ?", (is_update_of["id"],)).fetchone()
            score_db = get_completeness_score(dict(db_full))
            score_incoming = get_completeness_score(item)
            if score_incoming >= score_db:
                logger.info(f"Replacing duplicate DB entry {is_update_of['osm_id']} with richer incoming {item['osm_id']}")
                db_updates.append((is_update_of["id"], item))
            else:
                logger.info(f"Discarding duplicate incoming {item['osm_id']} in favor of richer DB entry {is_update_of['osm_id']}")
        else:
            items_to_insert.append(item)

    conn.close()

    # 3. Enforce image uniqueness across the entire set of items to be inserted/updated
    all_items_to_process = [item for _, item in db_updates] + items_to_insert
    
    # First, ensure real images are not duplicated across destinations
    used_real_images = _deduplicate_real_images(all_items_to_process)
    
    # Second, for all destinations that are now placeholders, assign them diverse images
    _minimize_placeholder_reuse(all_items_to_process, used_real_images)

    # 4. Write to DB
    count = 0
    # Perform inserts
    for item in items_to_insert:
        upsert_destination(app=app, **item)
        count += 1
        
    # Perform updates for richer duplicate matches
    if db_updates:
        conn = get_connection(app)
        for dest_id, item in db_updates:
            # Create a dictionary for the item, excluding osm_id for the update
            update_data = item.copy()
            update_data['id'] = dest_id # specify the record to update
            upsert_destination(app=app, **update_data)
            count += 1
        conn.close()

    # Note: The logic for deleting discarded OSM IDs is removed as the upsert/update
    # logic based on our primary key (UUID) and completeness score handles this implicitly.
    # We are replacing poorer records with richer ones, not just deleting.

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


def search_overpass(query: str, app=None, limit=12):
    """Live-search OpenStreetMap Overpass for matching places in Yaoundé.

    This powers the "search the internet" feature: when a user searches a
    destination that is not yet in our local database, we query Overpass
    for places whose name matches the query (case-insensitive substring)
    within the Yaoundé bounding box, normalize them with the same pipeline,
    and return them so the app can show results that we don't have locally.

    Returns a list of normalized destination dicts (already junk-filtered).
    """
    if not query or not query.strip():
        return []
    q = query.strip()
    try:
        # Overpass regex search over names (case-insensitive).
        escaped = re.escape(q.lower())
        search_query = f"""
[out:json][timeout:30];
(
  nwr["name"~"{escaped}",i]({YAOUNDE_BBOX});
  nwr["alt_name"~"{escaped}",i]({YAOUNDE_BBOX});
);
out center 12;
"""
        response = requests.get(
            OVERPASS_URL,
            params={"data": search_query},
            timeout=30,
            headers={"User-Agent": "YaoundeGlobeTrotter/1.0"},
        )
        response.raise_for_status()
        data = response.json()
        elements = data.get("elements", [])

        results = []
        for element in elements:
            try:
                normalized = _normalize_osm_element(element)
                if normalized and _has_junk_name(normalized["name"]) is False:
                    results.append(normalized)
                    if len(results) >= limit:
                        break
            except Exception:
                continue
        return results
    except Exception as e:
        logger.warning(f"Live Overpass search failed for '{query}': {e}")
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
                    count = sync_destinations(app)
                    logger.info(f"Periodic background destination sync completed: {count} destinations.")
            except Exception as e:
                logger.error(f"Periodic background destination sync failed: {e}", exc_info=True)

    thread = threading.Thread(target=run_sync_loop, daemon=True)
    thread.start()
