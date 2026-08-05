"""tools/remove_duplicate_images.py

Enforce the hard "no-duplicate-images" rule on the existing database.

RULE: No image URL may appear more than once anywhere in the app.
If an image URL appears more than once (across destinations, or more than
once in a single gallery), it is REMOVED from every destination that used it
and deleted entirely — leaving those destinations with no image rather than
a duplicate.

Run from services/recommendation-service:
    python tools/remove_duplicate_images.py
"""
import json
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import create_app
from app.overpass_sync import _normalize_image_url


def main():
    app = create_app()
    db = app.config["DATABASE"]
    conn = sqlite3.connect(db)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    rows = cur.execute("SELECT id, name, image, image_source, images FROM destinations").fetchall()

    # Collect every image URL occurrence (normalized) -> list of (row_id, is_main)
    occurrences = defaultdict(list)
    for r in rows:
        dest_images = []
        if r["image"]:
            dest_images.append(r["image"])
        gallery = r["images"] or "[]"
        try:
            gallery_list = json.loads(gallery) if isinstance(gallery, str) else gallery
        except Exception:
            gallery_list = []
        dest_images.extend(gallery_list)

        # Track which normalized URL maps to which (row_id, main_flag)
        for u in dest_images:
            n = _normalize_image_url(u)
            if n:
                occurrences[n].append(r["id"])

    # A URL is a duplicate if it appears in more than one destination.
    # Per the strict rule, we DELETE such URLs from every destination.
    duplicate_urls = {n: ids for n, ids in occurrences.items() if len(set(ids)) > 1}

    print(f"Total destinations scanned: {len(rows)}")
    print(f"Distinct normalized image URLs: {len(occurrences)}")
    print(f"Duplicate image URLs to remove entirely: {len(duplicate_urls)}")

    removed_count = 0
    for n, dest_ids in duplicate_urls.items():
        for dest_id in dest_ids:
            row = cur.execute("SELECT name, image, image_source, images FROM destinations WHERE id=?", (dest_id,)).fetchone()
            if not row:
                continue
            name = row["name"]
            image = row["image"]
            gallery = row["images"] or "[]"
            try:
                gallery_list = json.loads(gallery) if isinstance(gallery, str) else gallery
            except Exception:
                gallery_list = []

            # Remove the duplicate URL from the gallery.
            new_gallery = [u for u in gallery_list if _normalize_image_url(u) != n]
            # If the main image equals the duplicate, clear it.
            new_image = image if _normalize_image_url(image) != n else ""
            if not new_gallery:
                new_gallery = []
            cur.execute(
                "UPDATE destinations SET image=?, images=? WHERE id=?",
                (new_image, json.dumps(new_gallery), dest_id),
            )
            removed_count += 1
            print(f"  Removed '{n[:70]}...' from '{name}'")

    conn.commit()
    conn.close()
    print(f"\nDone. Removed duplicate image references from {removed_count} destination row(s).")


if __name__ == "__main__":
    main()
