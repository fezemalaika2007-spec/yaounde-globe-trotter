"""Diagnostic: find duplicate image URLs across the destinations DB.

This is a READ-ONLY diagnostic. It reports:
  1. Total destinations
  2. Total image URL occurrences vs distinct URLs
  3. Any URL that appears more than once (with which destinations)
  4. Breakdown of duplicates by image_source
  5. Within-gallery duplicates (same image twice in one destination)

Run from services/recommendation-service:
  python tools/diagnose_duplicates.py
"""
import json
import sqlite3
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import create_app


def normalize(u):
    """Minimal normalization for diagnosis: lowercase scheme/host, strip query/fragment."""
    from urllib.parse import urlsplit, urlunsplit
    try:
        p = urlsplit(u)
        scheme = (p.scheme or "https").lower()
        netloc = (p.netloc or "").lower()
        return urlunsplit((scheme, netloc, p.path.rstrip("/"), "", ""))
    except Exception:
        return u.strip().lower()


def main():
    app = create_app()
    conn = sqlite3.connect(app.config["DATABASE"])
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("SELECT name, image, image_source, images FROM destinations")
    rows = cur.fetchall()
    conn.close()

    total = len(rows)
    print(f"Total destinations: {total}\n")

    # Collect every image URL occurrence
    url_locations = defaultdict(list)  # normalized_url -> [(dest_name, raw_url, source)]
    within_gallery_dups = []

    for r in rows:
        name = r["name"]
        source = r["image_source"] or "?"
        raw_images = []
        if r["image"]:
            raw_images.append(r["image"])
        imgs = r["images"] or "[]"
        try:
            lst = json.loads(imgs) if isinstance(imgs, str) else imgs
        except Exception:
            lst = []
        raw_images.extend(lst)

        # Within-gallery duplicates
        seen_in_dest = {}
        for u in raw_images:
            n = normalize(u)
            seen_in_dest.setdefault(n, []).append(u)
        for n, urls in seen_in_dest.items():
            if len(urls) > 1:
                within_gallery_dups.append((name, urls))

        # Cross-destination locations
        for u in raw_images:
            url_locations[normalize(u)].append((name, u, source))

    all_occurrences = sum(len(v) for v in url_locations.values())
    print(f"Total image URL occurrences: {all_occurrences}")
    print(f"Distinct normalized URLs:   {len(url_locations)}\n")

    dups = {n: locs for n, locs in url_locations.items() if len(locs) > 1}
    print(f"=== CROSS-DESTINATION DUPLICATES: {len(dups)} ===")
    for n, locs in sorted(dups.items(), key=lambda kv: -len(kv[1]))[:30]:
        sources = set(l for _, _, l in locs)
        print(f"\n  [{len(locs)}x] {n}")
        for name, raw, src in locs:
            print(f"      - {src:12s} | {name} | {raw}")

    print(f"\n=== WITHIN-GALLERY DUPLICATES: {len(within_gallery_dups)} ===")
    for name, urls in within_gallery_dups[:20]:
        print(f"  {name}: {urls}")


if __name__ == "__main__":
    main()

