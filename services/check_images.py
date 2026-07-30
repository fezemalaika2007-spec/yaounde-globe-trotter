"""Check what images are stored for destinations in the recommendation service."""
import json, requests

resp = requests.get("http://localhost:5000/destinations?limit=728")
data = resp.json()

print(f"Total destinations: {len(data)}")
print()

# Count by image source
sources = {}
for d in data:
    s = d.get("image_source", "?")
    sources[s] = sources.get(s, 0) + 1
print("Image sources:", sources)
print()

# Show some with potential for real images
print("--- Showing destinations that might have wikidata tags ---")
count = 0
for d in data:
    name = d.get("name", "?")
    source = d.get("image_source", "?")
    img = d.get("image", "")
    tags = d.get("tags", [])

    if count < 20 and ("nature" in tags or "culture" in tags or "market" in tags):
        count += 1
        print(f"  Name: {name}")
        print(f"  Tags: {tags}")
        print(f"  Image source: {source}")
        print(f"  Image URL: {img[:80] if img else 'NONE'}")
        print()

if count == 0:
    print("No nature/culture/market destinations found yet")
    print("First 10 destinations:")
    for d in data[:10]:
        print(f"  {d.get('name','?')}: tags={d.get('tags',[])}")
