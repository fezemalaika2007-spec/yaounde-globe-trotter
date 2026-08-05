import json
import re
from urllib.parse import urlparse, unquote, quote

def normalize_image_url(url: str) -> str:
    """Normalize image URLs to a canonical form for robust deduplication."""
    if not url:
        return ""
    try:
        p = urlparse(url)
        
        path = p.path
        if "upload.wikimedia.org" in (p.netloc or ""):
            path = re.sub(r'/thumb/(.+?)/[^/]+$', r'/\1', path)

        netloc = (p.netloc or "").lower()
        if netloc.startswith("www."):
            netloc = netloc[4:]

        scheme = "https"
        path = quote(unquote(path.rstrip("/")))
        
        return f"{scheme}://{netloc}{path}"
        
    except Exception:
        return url.strip().lower().rstrip("/")

def find_duplicate_images(file_path):
    """
    Finds and reports duplicate image URLs in the destinations JSON file.
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        destinations = json.load(f)

    image_map = {}  # {normalized_url: [list of destination names]}
    
    for dest in destinations:
        dest_name = dest.get("name", "Unknown Destination")
        image_urls = dest.get("images", [])
        
        # As per user request, we are looking for REAL image duplicates.
        # The image_source being 'placeholder' is a different issue (placeholder reuse).
        # We will focus on where image_source is 'wikimedia' or 'osm'.
        # However, for the initial investigation, let's check ALL images to be thorough.
        # We can filter by image_source later if needed.

        for url in image_urls:
            normalized_url = normalize_image_url(url)
            if normalized_url not in image_map:
                image_map[normalized_url] = []
            image_map[normalized_url].append(dest_name)

    duplicates_found = False
    print("--- Duplicate Image Report ---")
    for url, names in image_map.items():
        if len(names) > 1:
            duplicates_found = True
            print(f"\n[DUPLICATE FOUND] URL: {url}")
            print(f"Appears in {len(names)} destinations:")
            for name in names:
                print(f"  - {name}")
    
    if not duplicates_found:
        print("\nNo duplicate image URLs found across all destinations.")
    
    print("\n--- End of Report ---")

if __name__ == "__main__":
    find_duplicate_images("destinations.json")
