"""recommendation-service/import_utils.py

Processes web URLs provided by the user to extract destination metadata
(title, description, image, area/location) and saves them to the database.
"""
import re
import json
import uuid
import datetime
import urllib.request
from urllib.parse import urlparse
from html.parser import HTMLParser

from app.models import get_connection, release_connection


class SimpleMetaParser(HTMLParser):
    """Parses HTML to extract title, og:title, og:image, og:description, meta description."""
    def __init__(self):
        super().__init__()
        self.title = ""
        self.og_title = ""
        self.og_image = ""
        self.og_description = ""
        self.meta_description = ""
        self.in_title = False

    def handle_starttag(self, tag, attrs):
        attrs_dict = {k.lower(): v for k, v in attrs if k and v}
        if tag.lower() == "title":
            self.in_title = True
        elif tag.lower() == "meta":
            prop = attrs_dict.get("property", "").lower()
            name = attrs_dict.get("name", "").lower()
            content = attrs_dict.get("content", "").strip()

            if prop == "og:title":
                self.og_title = content
            elif prop == "og:image":
                self.og_image = content
            elif prop == "og:description":
                self.og_description = content
            elif name == "description":
                self.meta_description = content

    def handle_endtag(self, tag):
        if tag.lower() == "title":
            self.in_title = False

    def handle_data(self, data):
        if self.in_title:
            self.title += data


def extract_metadata_from_url(url: str) -> dict:
    """Fetch URL and parse HTML metadata to build a destination dictionary."""
    url = url.strip()
    if not url.startswith("http://") and not url.startswith("https://"):
        url = "https://" + url

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }

    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            html = resp.read().decode("utf-8", errors="ignore")

        parser = SimpleMetaParser()
        parser.feed(html)

        name = parser.og_title or parser.title.strip()
        # Clean common site name suffixes from title
        name = re.sub(r'\s*[-|–—]\s*.*$', '', name).strip()
        if not name:
            name = urlparse(url).netloc

        description = parser.og_description or parser.meta_description or f"Destination from {urlparse(url).netloc}"
        image = parser.og_image or ""

        # Make relative image URLs absolute
        if image and not image.startswith("http"):
            parsed = urlparse(url)
            image = f"{parsed.scheme}://{parsed.netloc}{image}"

        return {
            "name": name,
            "description": description,
            "image": image,
            "website": url,
            "category": "Attraction",
            "area": "Yaoundé",
            "cost": 0,
            "tags": ["user-added"],
            "star_rating": 4.5,
            "average_rating": 4.5,
            "rating_count": 1,
        }
    except Exception as e:
        print(f"Error fetching URL {url}: {e}")
        # Fallback dictionary if URL fetching is blocked or fails
        parsed = urlparse(url)
        return {
            "name": parsed.path.split("/")[-1].replace("-", " ").replace("_", " ").capitalize() or parsed.netloc,
            "description": f"Imported destination from {url}",
            "image": "",
            "website": url,
            "category": "Attraction",
            "area": "Yaoundé",
            "cost": 0,
            "tags": ["user-added"],
            "star_rating": 4.0,
            "average_rating": 4.0,
            "rating_count": 1,
        }


def save_destination_from_dict(d: dict, app=None) -> str:
    """Insert a new destination object into the destinations table."""
    conn = get_connection(app)
    cur = conn.cursor()
    dest_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    tags_json = json.dumps(d.get("tags", []))
    activities_json = json.dumps(d.get("activities", []))
    facilities_json = json.dumps(d.get("facilities", []))
    images_json = json.dumps(d.get("images", [d["image"]] if d.get("image") else []))

    cur.execute("""
        INSERT INTO destinations (
            id, fsq_id, name, area, tags, description, long_description,
            cost, image, image_source, latitude, longitude, address,
            category, activities, opening_hours, website, average_rating,
            rating_count, star_rating, facilities, images, last_synced_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'user-import', %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        dest_id, f"import-{dest_id[:8]}", d.get("name", "Untitled Place"),
        d.get("area", "Yaoundé"), tags_json, d.get("description", ""),
        d.get("long_description", d.get("description", "")), d.get("cost", 0),
        d.get("image", ""), d.get("latitude"), d.get("longitude"),
        d.get("address", ""), d.get("category", "Attraction"),
        activities_json, d.get("opening_hours", "Open 24/7"),
        d.get("website", ""), d.get("average_rating", 4.5),
        d.get("rating_count", 1), d.get("star_rating", 4.5),
        facilities_json, images_json, now
    ))

    conn.commit()
    cur.close()
    release_connection(conn)
    return dest_id
