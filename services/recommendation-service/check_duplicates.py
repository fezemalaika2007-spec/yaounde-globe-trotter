
import json
from collections import defaultdict

def find_duplicate_images():
    with open('destinations.json', 'r', encoding='utf-8') as f:
        destinations = json.load(f)

    image_counts = defaultdict(list)
    for dest in destinations:
        if 'images' in dest and dest['images']:
            for image in dest['images']:
                image_counts[image].append(dest['name'])

    duplicates = {image: names for image, names in image_counts.items() if len(names) > 1}

    if duplicates:
        print("Found duplicate images:")
        for image, names in duplicates.items():
            print(f"  Image: {image}")
            print(f"  Used in: {', '.join(names)}")
            print()
    else:
        print("No duplicate images found in destinations.json")

if __name__ == "__main__":
    find_duplicate_images()
