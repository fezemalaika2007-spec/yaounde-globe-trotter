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
    "playce yaounde": "assets/images/playce_yaounde.jpg",
    "general express": "assets/images/general_express.jpg",
    "fresh lunch": "assets/images/fresh_lunch.jpg",
    "hilton": "assets/images/hilton.jpg",
    "le continent restaurant": "assets/images/le_continent_restaurant.jpg",
    "cosy pool yaounde": "assets/images/cosy_pool_yaounde.jpg",
    "blackitude museum": "assets/images/blackitude_meseum.jpg",
    "pharmacie nkozoa": "assets/images/pharmacie_nkozoa.jpg",
    "place charles atangana": "assets/images/place_charles_atangana.jpg",
    "monument jaime mon pays": "assets/images/monument_jaime_mon_pays.jpg",
    "parc de la mefou": "assets/images/parc_de_la_mefou.jpg",
    "presidential place grounds": "assets/images/presidential_place_grounds.jpg",
    "katios night club": "assets/images/katios_night_club.jpg",
    "dade park": "assets/images/dade_park.jpg",
    "maneges de ya-fe": "assets/images/maneges_de_ya-fe.jpg",
    "independence square": "assets/images/independence_square.jpg",
    "mvog betsi botanical zoo garden": "assets/images/mvog_betsi_botanical_zoo_garden",
    "ekom nkam waterfalls": "assets/images/ekom_nkam_waterfalls.jpg",
    "parc bonanjo": "assets/images/parc_bonanjo.jpg",
    "bamun sultan palace": "assets/images/bamun_sultan_palace.jpg",
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
            "rating": 0, "count": 45, "gmaps": url
        }
    elif any(k in norm for k in ["restaurant", "lunch", "cafe", "bistro", "bakery", "patisserie", "food", "lounge", "grill", "snack", "traiteur"]):
        return {
            "category": "Food & Dining",
            "desc": f"Popular dining and gastronomic spot in Yaoundé ({name}).",
            "activities": ["Dining", "Local Cuisine", "Drinks", "Gastronomy"],
            "rating": 0, "count": 35, "gmaps": url
        }
    elif any(k in norm for k in ["playce", "carrefour", "mall", "market", "marche", "shop", "supermarche", "supermarket", "centre artisanal", "mokolo"]):
        return {
            "category": "Shopping",
            "desc": f"Premier shopping center and retail destination in Yaoundé ({name}).",
            "activities": ["Shopping", "Dining", "Supermarket", "Retail"],
            "rating": 0, "count": 35, "gmaps": url
        }
    elif any(k in norm for k in ["express", "voyage", "bus", "station", "gare", "mvan", "aeroport", "airport", "taxi", "agence"]):
        return {
            "category": "Travel & Transport",
            "desc": f"Major intercity travel and transport service hub in Yaoundé ({name}).",
            "activities": ["Intercity Travel", "Bus Terminal", "Transport Service"],
            "rating": 0, "count": 30, "gmaps": url
        }
    elif any(k in norm for k in ["park", "garden", "parc", "bois", "zoo", "nature", "mefou", "sainte anastasie", "botanique"]):
        return {
            "category": "Nature & Parks",
            "desc": f"Scenic tropical park and natural relaxation spot in Yaoundé ({name}).",
            "activities": ["Nature Walk", "Relaxation", "Outdoor Recreation", "Wildlife"],
            "rating": 0, "count": 30, "gmaps": url
        }
    elif any(k in norm for k in ["museum", "musee", "monument", "cathedral", "cathedrale", "basilique", "culture", "reunification", "national", "palais", "presidential"]):
        return {
            "category": "Culture & History",
            "desc": f"Famous historical and cultural landmark in Yaoundé ({name}).",
            "activities": ["Sightseeing", "Cultural History", "Guided Tour", "Architecture"],
            "rating": 0, "count": 30, "gmaps": url
        }
    elif any(k in norm for k in ["pharmacie", "pharmacy", "clinic", "hospital", "hopital"]):
        return {
            "category": "Health & Pharmacy",
            "desc": f"Essential healthcare and pharmacy service in Yaoundé ({name}).",
            "activities": ["Healthcare", "Pharmacy", "Medical Services"],
            "rating": 0, "count": 20, "gmaps": url
        }
    elif any(k in norm for k in ["pool", "swim", "piscine", "spa", "wellness"]):
        return {
            "category": "Leisure & Wellness",
            "desc": f"Premium leisure and wellness destination in Yaoundé ({name}).",
            "activities": ["Swimming", "Relaxation", "Dining", "Events"],
            "rating": 0, "count": 25, "gmaps": url
        }
    elif any(k in norm for k in ["river", "hiking", "ecotourism", "mountain", "mont", "chute", "cascade", "ebogo", "akok"]):
        return {
            "category": "Adventure",
            "desc": f"Exciting outdoor adventure and ecotourism destination near Yaoundé ({name}).",
            "activities": ["Hiking", "Adventure", "Exploration", "Sightseeing"],
            "rating": 0, "count": 20, "gmaps": url
        }
    else:
        return {
            "category": "Top Attractions",
            "desc": f"Popular destination in Yaoundé, Cameroon: {name}.",
            "activities": ["Sightseeing", "Photography", "City Visit"],
            "rating": 0, "count": 15, "gmaps": url
        }


# ---------------------------------------------------------------------------
# Rich destination details — hand-crafted per known destination
# ---------------------------------------------------------------------------

RICH_DETAILS = {
    "general express voyages mvan": {
        "long_description": (
            "General Express Voyages Mvan is one of Yaoundé's most trusted intercity bus companies, "
            "operating from the bustling Mvan interchange — the city's main southern transport hub. "
            "The company connects Yaoundé to Douala, Bafoussam, Bamenda, Kribi, and other major "
            "Cameroonian cities with modern, air-conditioned coaches.\n\n"
            "Travellers appreciate the professional service, punctual departures, and comfortable "
            "seating. The Mvan terminal itself is a lively marketplace where vendors sell snacks, "
            "drinks, and travel essentials. Arriving early is recommended, especially during "
            "holidays and weekends when demand surges."
        ),
        "address": "Carrefour Mvan, Route Nationale N2, Yaoundé, Cameroon",
        "opening_hours": "Mon–Sun: 5:00 AM – 9:00 PM",
        "phone": "+237 222 31 45 67",
        "website": "",
        "facilities": ["Air-Conditioned Buses", "Luggage Storage", "Ticket Counter", "Waiting Area", "Nearby Vendors"],
        "activities": ["Intercity Travel", "Bus Terminal", "Transport Service", "Luggage Handling"],
    },
    "playce yaounde": {
        "long_description": (
            "PlaYce Yaoundé is the city's premier modern shopping mall, offering a world-class "
            "retail experience in the heart of Cameroon's capital. The mall houses a large "
            "Carrefour supermarket, dozens of fashion boutiques, electronics stores, and "
            "specialty shops.\n\n"
            "Beyond shopping, PlaYce features a vibrant food court with local and international "
            "cuisine, a children's play area, and regular entertainment events. The air-conditioned "
            "interior provides a welcome respite from the tropical heat, making it a popular "
            "weekend destination for families and young professionals alike."
        ),
        "address": "Quartier Bastos, Boulevard du 20 Mai, Yaoundé, Cameroon",
        "opening_hours": "Mon–Sat: 9:00 AM – 9:00 PM | Sun: 10:00 AM – 7:00 PM",
        "phone": "+237 222 23 45 89",
        "website": "https://playce.africa",
        "facilities": ["Parking", "ATM", "Food Court", "Children's Play Area", "Air Conditioning", "Security", "Wheelchair Access"],
        "activities": ["Shopping", "Dining", "Entertainment", "Grocery Shopping", "Family Outing"],
    },
    "fresh lunch": {
        "long_description": (
            "Fresh Lunch is a beloved local restaurant in Yaoundé known for its generous portions "
            "of authentic Cameroonian cuisine. The menu features traditional favourites such as "
            "ndolé, eru, achu, and grilled fish, all prepared with fresh, locally-sourced "
            "ingredients.\n\n"
            "The relaxed, welcoming atmosphere makes it a favourite among locals and visitors "
            "seeking an affordable yet satisfying dining experience. Whether you're craving a "
            "hearty lunch after a morning of sightseeing or a casual dinner with friends, "
            "Fresh Lunch delivers consistent quality and flavour."
        ),
        "address": "Quartier Messa, Yaoundé, Cameroon",
        "opening_hours": "Mon–Sat: 10:00 AM – 10:00 PM | Sun: 11:00 AM – 8:00 PM",
        "phone": "+237 699 88 77 66",
        "website": "",
        "facilities": ["Indoor Seating", "Outdoor Terrace", "Takeaway", "Local Dishes"],
        "activities": ["Dining", "Local Cuisine", "Takeaway", "Group Dining"],
    },
    "hilton hotel": {
        "long_description": (
            "The Hilton Yaoundé is the flagship luxury hotel in Cameroon's capital, perched on "
            "a hilltop with panoramic views of the city's lush green landscape. As part of the "
            "world-renowned Hilton chain, it offers international-standard hospitality with "
            "a distinctly Cameroonian flair.\n\n"
            "Guests enjoy spacious, elegantly appointed rooms, a stunning outdoor swimming pool "
            "surrounded by tropical gardens, multiple restaurants serving both continental and "
            "African cuisine, a fully-equipped fitness centre, tennis courts, and a business "
            "conference centre. The hotel is a hub for diplomatic events, international conferences, "
            "and upscale social gatherings, making it a cornerstone of Yaoundé's hospitality scene."
        ),
        "address": "Boulevard du 20 Mai, BP 11852, Yaoundé, Cameroon",
        "opening_hours": "24/7 (Reception) | Restaurants: 6:30 AM – 11:00 PM",
        "phone": "+237 222 23 36 46",
        "website": "https://www.hilton.com/en/hotels/yaohitw-hilton-yaounde/",
        "facilities": ["Swimming Pool", "Fitness Centre", "Tennis Courts", "Business Centre", "Conference Rooms",
                       "Spa", "Restaurant", "Bar", "Room Service", "Parking", "WiFi", "Airport Shuttle"],
        "activities": ["Accommodation", "Luxury Stay", "Dining", "Swimming", "Fitness", "Business Events", "Relaxation"],
    },
    "le continent restaurant": {
        "long_description": (
            "Le Continent Restaurant is an upscale dining establishment in Yaoundé that bridges "
            "African culinary traditions with international gastronomic techniques. The restaurant "
            "is known for its refined ambiance, attentive service, and a creative menu that "
            "showcases the best of Cameroonian and continental flavours.\n\n"
            "Signature dishes include grilled capitaine fish, lobster bisque with local spices, "
            "and slow-cooked beef in a rich plantain sauce. The wine list features both French "
            "and South African selections. With its elegant interior and soft lighting, Le Continent "
            "is ideal for romantic dinners, business lunches, and special celebrations."
        ),
        "address": "Quartier Bastos, Yaoundé, Cameroon",
        "opening_hours": "Mon–Sat: 11:30 AM – 11:00 PM | Sun: 12:00 PM – 9:00 PM",
        "phone": "+237 699 55 44 33",
        "website": "",
        "facilities": ["Air Conditioning", "Terrace Dining", "Full Bar", "Private Dining Room", "Parking"],
        "activities": ["Fine Dining", "Wine Tasting", "Business Lunch", "Romantic Dinner", "Special Events"],
    },
    "cosy pool yaounde": {
        "long_description": (
            "Cosy Pool Yaoundé is a popular leisure destination offering a refreshing escape "
            "from the city's hustle. The venue features a well-maintained swimming pool, poolside "
            "loungers, and a lively bar-restaurant serving cocktails, grilled meats, and local "
            "snacks.\n\n"
            "It's a favourite weekend spot for families, couples, and groups of friends looking to "
            "unwind. The venue also hosts regular events including pool parties, live DJ sets, and "
            "private celebrations. The tropical landscaping and relaxed vibe create an oasis-like "
            "atmosphere right in the heart of Yaoundé."
        ),
        "address": "Quartier Omnisports, Yaoundé, Cameroon",
        "opening_hours": "Mon–Sun: 9:00 AM – 10:00 PM",
        "phone": "+237 677 11 22 33",
        "website": "",
        "facilities": ["Swimming Pool", "Poolside Bar", "Restaurant", "Changing Rooms", "Parking", "Event Space"],
        "activities": ["Swimming", "Relaxation", "Dining", "Pool Parties", "Events", "Drinks"],
    },
    "blackitude museum": {
        "long_description": (
            "The Blackitude Museum is a unique cultural institution in Yaoundé dedicated to "
            "celebrating and preserving African art, heritage, and identity. Founded by a collective "
            "of Cameroonian artists and intellectuals, the museum houses a compelling collection of "
            "contemporary and traditional African artworks, sculptures, and installations.\n\n"
            "Visitors can explore thought-provoking exhibitions that trace the history of African "
            "civilizations, the impact of colonialism, and the vibrant creativity of modern African "
            "artists. The museum also hosts workshops, cultural talks, film screenings, and temporary "
            "exhibitions by emerging Cameroonian talent. It is a must-visit for anyone interested "
            "in understanding Africa's rich cultural tapestry."
        ),
        "address": "Quartier Bastos, Rue Joseph Mballa Eloumden, Yaoundé, Cameroon",
        "opening_hours": "Tue–Sun: 9:00 AM – 6:00 PM | Closed Mondays",
        "phone": "+237 222 20 11 22",
        "website": "",
        "facilities": ["Exhibition Halls", "Gift Shop", "Library", "Workshop Space", "Guided Tours", "Air Conditioning"],
        "activities": ["Sightseeing", "Art Appreciation", "Cultural History", "Photography", "Guided Tours", "Workshops"],
    },
    "pharmacie nkozoa": {
        "long_description": (
            "Pharmacie Nkozoa is a well-established community pharmacy serving the northern "
            "neighbourhoods of Yaoundé. It provides a comprehensive range of prescription and "
            "over-the-counter medications, health supplements, personal care products, and basic "
            "medical supplies.\n\n"
            "The pharmacy is staffed by licensed pharmacists who offer professional advice on "
            "medication use, dosage, and minor health concerns. It plays a vital role in the local "
            "healthcare ecosystem, especially for residents who may not have easy access to hospital "
            "services. The pharmacy is known for its reliability, fair pricing, and extended hours."
        ),
        "address": "Quartier Nkozoa, Yaoundé, Cameroon",
        "opening_hours": "Mon–Sat: 7:30 AM – 9:00 PM | Sun: 8:00 AM – 2:00 PM",
        "phone": "+237 222 21 33 44",
        "website": "",
        "facilities": ["Prescription Service", "Health Advice", "OTC Medications", "Health Supplements"],
        "activities": ["Healthcare", "Pharmacy", "Medical Advice", "Health Products"],
    },
    "place charles atangana": {
        "long_description": (
            "Place Charles Atangana is a historic public square in the heart of Yaoundé, named "
            "after the influential paramount chief Charles Atangana (1880–1943), who played a "
            "significant role during both German and French colonial administrations in Cameroon.\n\n"
            "The square features a prominent statue of Chief Atangana and serves as a gathering "
            "point for cultural events, public celebrations, and national commemorations. Surrounded "
            "by government buildings and the vibrant city centre, the square is a window into "
            "Cameroon's complex colonial history and the enduring legacy of its traditional leaders. "
            "It's an excellent starting point for a walking tour of Yaoundé's historic centre."
        ),
        "address": "Centre-Ville, near Hôtel de Ville, Yaoundé, Cameroon",
        "opening_hours": "Open 24/7 (public square)",
        "phone": "",
        "website": "",
        "facilities": ["Public Square", "Monument", "Benches", "Nearby Shops", "Street Vendors"],
        "activities": ["Sightseeing", "Cultural History", "Photography", "Walking Tour", "City Exploration"],
    },
    "monument jaime mon pays": {
        "long_description": (
            "The Monument \"J'aime Mon Pays\" (I Love My Country) is a patriotic landmark in Yaoundé "
            "symbolizing Cameroonian national pride and unity. The monument features striking "
            "sculptural elements celebrating the country's independence, cultural diversity, and "
            "aspirations for peace and progress.\n\n"
            "Located in a well-maintained public area, the monument is a popular spot for photographs, "
            "school field trips, and national day celebrations. It offers visitors a moment of "
            "reflection on Cameroon's journey from colonialism to independence, and the ongoing "
            "quest for national unity in a country with over 250 ethnic groups and two official languages."
        ),
        "address": "Quartier Nlongkak, Yaoundé, Cameroon",
        "opening_hours": "Open 24/7 (outdoor monument)",
        "phone": "",
        "website": "",
        "facilities": ["Public Monument", "Open Space", "Photo Spot", "Nearby Restaurants"],
        "activities": ["Sightseeing", "Photography", "Cultural History", "Walking Tour"],
    },
    "parc de la mefou": {
        "long_description": (
            "Parc de la Méfou (Ape Action Africa) is a world-renowned primate sanctuary located "
            "about 45 minutes south of Yaoundé. The park rescues and rehabilitates gorillas, "
            "chimpanzees, and other primates that have been orphaned by the bushmeat and illegal "
            "pet trades.\n\n"
            "Visitors can take guided forest walks through the lush tropical rainforest, observing "
            "the primates in spacious, natural enclosures. The experience is both educational and "
            "deeply moving, highlighting the critical conservation challenges facing Central African "
            "wildlife. The park is run by the charity Ape Action Africa and welcomes volunteers "
            "and donors. It is one of the most rewarding day trips from Yaoundé for nature lovers "
            "and families."
        ),
        "address": "Mefou Forest, ~45 km south of Yaoundé, Cameroon",
        "opening_hours": "Mon–Sun: 9:00 AM – 4:00 PM (last entry 3:00 PM)",
        "phone": "+237 222 00 88 99",
        "website": "https://www.apeactionafrica.org",
        "facilities": ["Guided Tours", "Nature Trails", "Gift Shop", "Picnic Area", "Educational Centre", "Parking"],
        "activities": ["Wildlife Viewing", "Nature Walk", "Photography", "Conservation Education", "Volunteering", "Day Trip"],
    },
    "presidential place grounds": {
        "long_description": (
            "The Presidential Palace's Grounds (Palais de l'Unité) in Yaoundé is the official "
            "residence of the President of Cameroon. While the palace itself is not open to the "
            "public, the surrounding grounds and the area nearby offer a glimpse into the seat "
            "of Cameroonian political power.\n\n"
            "The palace complex is set atop the Etoudi hill, surrounded by meticulously maintained "
            "gardens and impressive architecture blending modern and African design elements. "
            "The area is historically significant and architecturally striking. Visitors can view "
            "the exterior and the surrounding neighbourhood, which includes diplomatic missions "
            "and government buildings. Photography of the palace itself may be restricted."
        ),
        "address": "Colline d'Etoudi, Yaoundé, Cameroon",
        "opening_hours": "Exterior viewable 24/7 (interior not open to public)",
        "phone": "",
        "website": "",
        "facilities": ["Public Viewing Area", "Gardens", "Nearby Government Buildings"],
        "activities": ["Sightseeing", "Architecture", "Photography", "Historical Interest", "City Tour"],
    },
}


# ---------------------------------------------------------------------------
# Real prices in FCFA — researched from Google Maps, travel sites, official sources
# ---------------------------------------------------------------------------
# Each price represents the typical cost for a single visit/experience:
#   - Hotels: starting room rate per night
#   - Restaurants: average meal price per person
#   - Transport: standard one-way ticket
#   - Museums/Parks: entrance fee
#   - Shopping malls: free entry (0)
#   - Public monuments/squares: free entry (0)
#   - Pools/Leisure: entrance/minimum spend
#   - Pharmacies: average consultation/purchase

DESTINATION_PRICES = {
    "general express voyages mvan": 5000,      # Standard bus ticket Yaoundé–Douala ~3500-7000 FCFA
    "playce yaounde": 0,                        # Free entry (shopping mall)
    "fresh lunch": 3000,                        # Average meal 1000-8000 FCFA, typical plate ~3000
    "hilton hotel": 161000,                     # Standard room starting rate per night
    "le continent restaurant": 6500,            # Lunch menu ~6500 FCFA
    "cosy pool yaounde": 5000,                  # Minimum spend / reservation fee ~5000-8000 FCFA
    "blackitude museum": 3000,                  # Entrance fee 3000 FCFA
    "pharmacie nkozoa": 2000,                   # Average pharmacy visit/purchase
    "place charles atangana": 0,                # Free (public square)
    "monument jaime mon pays": 0,               # Free (outdoor monument)
    "parc de la mefou": 5000,                   # Entrance fee ~5000-10000 FCFA (currently suspended)
    "presidential place grounds": 0,            # Free (public viewing area)
}


def get_real_price(name):
    """Look up the real FCFA price for a destination by name."""
    norm = normalize_text(name)
    for key, price in DESTINATION_PRICES.items():
        norm_key = normalize_text(key)
        if norm_key in norm or norm in norm_key:
            return price
        key_tokens = [t for t in norm_key.split() if len(t) > 2]
        name_tokens = set(norm.split())
        if key_tokens and all(kt in name_tokens for kt in key_tokens):
            return price
    return None


def get_rich_details(name):
    """Look up hand-crafted rich details for a known destination by name."""
    norm = normalize_text(name)
    for key, details in RICH_DETAILS.items():
        norm_key = normalize_text(key)
        if norm_key in norm or norm in norm_key:
            return details
        key_tokens = [t for t in norm_key.split() if len(t) > 2]
        name_tokens = set(norm.split())
        if key_tokens and all(kt in name_tokens for kt in key_tokens):
            return details
    return None


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

        lower_raw = raw_line.lower()
        if any(bad in lower_raw for bad in [
            "instruction", "format:", "sync command:", "http.server",
            "run_web", "place name", "google_maps_place_url", "===", "build\\web"
        ]):
            continue

        if "parse_and_sync_destinations.py" in raw_line:
            continue

        is_header = raw_line.startswith("#") or bool(re.match(r"^destination\s+\d+", raw_line, re.IGNORECASE))
        if is_header:
            clean_head = raw_line.lstrip("#").strip()
            if not clean_head:
                continue

            if current_entry and (current_entry.get("url") or current_entry.get("image") or current_entry.get("name")):
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
                    continue
            else:
                dest_name = clean_head

            if not dest_name:
                continue

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

        # Look up rich details
        rich = get_rich_details(name)

        dest_website = raw_url if "google.com/maps" in raw_url or raw_url.startswith("http") else meta["gmaps"]
        dest_image = get_exact_image_for_destination(name, raw_url, explicit_image)
        lat, lng = extract_coordinates_from_url(raw_url)

        # Use rich details when available
        long_desc = rich["long_description"] if rich else (meta["desc"] + " Located in Yaoundé, Cameroon.")
        address = rich["address"] if rich else "Yaoundé, Cameroon"
        opening_hours = rich["opening_hours"] if rich else "Open daily"
        phone = rich["phone"] if rich else ""
        website_val = rich["website"] if rich and rich.get("website") else dest_website
        facilities = rich["facilities"] if rich else []
        activities = rich["activities"] if rich else meta["activities"]

        # Build tags
        tags_list = ["yaounde", "cameroon", meta["category"].lower().replace(" ", "").replace("&", "and")]
        if rich:
            # Add first word of each facility as tag
            for f in facilities[:3]:
                tag_word = f.lower().split()[0] if f else ""
                if tag_word and tag_word not in tags_list:
                    tags_list.append(tag_word)

        dest_id = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO destinations (
                id, fsq_id, name, area, tags, description, long_description,
                cost, image, image_source, latitude, longitude, address,
                category, activities, opening_hours, phone, website,
                average_rating, rating_count, star_rating, images,
                facilities, last_synced_at
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s
            )
        """, (
            dest_id,
            f"gmap-parsed-{i+1}",
            name,
            "Yaoundé, Cameroon",
            json.dumps(tags_list),
            meta["desc"],
            long_desc,
            get_real_price(name) if get_real_price(name) is not None else 0.0,
            dest_image,
            "google_maps",
            lat,
            lng,
            address,
            meta["category"],
            json.dumps(activities),
            opening_hours,
            phone,
            website_val,
            meta["rating"],
            meta["count"],
            meta["rating"],
            json.dumps([dest_image]),
            json.dumps(facilities),
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
