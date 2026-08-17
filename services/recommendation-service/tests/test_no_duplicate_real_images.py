"""tests/test_no_duplicate_real_images.py

App-wide no-duplicate-image test.

Enforces the hard product rule: NO image URL may appear more than once across
the entire destinations dataset. Since we now source all images from
Foursquare (each photo is unique to its venue), this is a pure safety net.

The test reads every destination from the database, collects every image URL
(including the `image` main field and every entry in the `images` gallery),
normalizes each URL, and asserts that no normalized URL appears more than once.

Run from services/recommendation-service:
    python -m pytest tests/test_no_duplicate_real_images.py -q

This test is part of the permanent app-wide test suite, not a one-off.
"""
import json
import os
import sys
from collections import defaultdict
from pathlib import Path

import pytest

# Ensure the service dir is importable.
_service_dir = str(Path(__file__).resolve().parents[1])
if _service_dir not in sys.path:
    sys.path.insert(0, _service_dir)

from app import create_app
from app.image_utils import _normalize_image_url


@pytest.fixture(scope="module")
def all_destinations():
    """Return all destinations currently in the DB.

    Requires the online PostgreSQL connection string (DATABASE_URL). If it is
    not configured (e.g. in CI without credentials), the test is skipped so the
    suite still passes without network/DB access.
    """
    if not (os.environ.get("DATABASE_URL") or "").strip():
        pytest.skip(
            "DATABASE_URL not set; skipping online no-duplicate-image check."
        )

    from app.models import init_db, get_all_destinations

    app = create_app()
    with app.app_context():
        init_db(app)
        return get_all_destinations(app)


def _iter_image_urls(destination):
    """Yield every image URL for a destination (main image + gallery)."""
    main = destination.get("image") or ""
    if main:
        yield main
    gallery = destination.get("images") or []
    for url in gallery:
        if url:
            yield url


def test_no_duplicate_images_across_dataset(all_destinations):
    """Assert no normalized image URL appears more than once across the dataset."""
    if not all_destinations:
        pytest.skip("No destinations in database to test.")

    locations = defaultdict(list)  # normalized_url -> list of destination names
    for dest in all_destinations:
        name = dest.get("name") or "?"
        seen_in_dest = set()
        for raw in _iter_image_urls(dest):
            n = _normalize_image_url(raw)
            if not n:
                continue
            # Ignore the same destination listing the same URL in both `image`
            # and `images[0]` (that is by-design, not a duplicate).
            if n in seen_in_dest:
                continue
            seen_in_dest.add(n)
            locations[n].append(name)

    duplicates = {u: names for u, names in locations.items() if len(names) > 1}
    assert not duplicates, (
        f"Found {len(duplicates)} image URL(s) used by more than one destination: "
        + ", ".join(f"{u} -> {names}" for u, names in list(duplicates.items())[:5])
    )


def test_no_duplicate_images_within_any_gallery(all_destinations):
    """Assert no gallery contains the same normalized URL twice."""
    if not all_destinations:
        pytest.skip("No destinations in database to test.")

    for dest in all_destinations:
        gallery = dest.get("images") or []
        normalized = [_normalize_image_url(u) for u in gallery if u]
        normalized = [n for n in normalized if n]
        assert len(normalized) == len(set(normalized)), (
            f"Destination '{dest.get('name')}' has a duplicate image in its gallery: {gallery}"
        )


def test_initial_seed_destinations_have_unique_real_images():
    """Assert all INITIAL_SEED_DESTINATIONS have unique, valid image URLs."""
    from app.models import INITIAL_SEED_DESTINATIONS

    seen_urls = {}
    for dest in INITIAL_SEED_DESTINATIONS:
        name = dest.get("name")
        raw_url = dest.get("image")
        assert raw_url and raw_url.startswith("https://"), (
            f"Seed destination '{name}' must have a valid HTTPS image URL"
        )
        norm = _normalize_image_url(raw_url)
        assert norm not in seen_urls, (
            f"Duplicate seed image URL found for '{name}': {raw_url} (already used by '{seen_urls[norm]}')"
        )
        seen_urls[norm] = name

