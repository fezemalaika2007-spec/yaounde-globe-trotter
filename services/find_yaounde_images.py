"""Find real Wikimedia Commons images related to Yaounde, Cameroon."""
import requests
import json

# Search for real Yaounde images on Wikimedia Commons
categories = [
    "Yaoundé",
    "Yaoundé market",
    "Yaoundé restaurant",
    "Yaoundé nature",
    "Yaoundé hotel",
    "Yaoundé museum",
    "Yaoundé monument",
    "Yaoundé park",
    "Yaoundé sport",
    "Yaoundé landscape",
    "Yaoundé building",
    "Yaoundé street",
    "Yaoundé culture",
    "Yaoundé landmark",
    "Yaoundé food",
    "Yaoundé nightlife",
]

seen = set()
for cat in categories:
    try:
        r = requests.get(
            "https://commons.wikimedia.org/w/api.php",
            params={
                "action": "query",
                "list": "search",
                "srsearch": cat,
                "srnamespace": "6",  # File namespace
                "srlimit": 5,
                "format": "json",
            },
            timeout=10,
            headers={"User-Agent": "YaoundeGlobeTrotter/1.0"},
        )
        data = r.json()
        results = data.get("query", {}).get("search", [])
        for s in results:
            title = s["title"]
            if title not in seen:
                seen.add(title)
                # Extract filename from "File:xxx.jpg"
                filename = title.replace("File:", "", 1)
                print(f"  Category '{cat}': {filename}")
    except Exception as e:
        print(f"  Error for '{cat}': {e}")

print(f"\nTotal unique images found: {len(seen)}")
