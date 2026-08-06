"""tests/test_foursquare_sync.py — pytest suite for the Foursquare sync.

Mocks the Foursquare Places API responses and verifies:
  * venues with zero photos are excluded (Step 3A)
  * no duplicate image URLs across the dataset (Step 3)
  * venues with photos are normalized and kept
"""
import sys
from pathlib import Path

# Ensure the service directory is on sys.path so "app" is importable.
_service_dir = str(Path(__file__).resolve().parents[1])
if _service_dir not in sys.path:
    sys.path.insert(0, _service_dir)

import pytest

from app import foursquare_sync as fs
from app.image_utils import _normalize_image_url


def _venue(fsq_id, name, has_photo=True, category="16032", price=2):
    """Build a Foursquare venue-like dict."""
    photos = []
    if has_photo:
        photos = [{"prefix": "https://fastly.4sqi.net/img/general/",
                   "suffix": f"/{fsq_id}_hash.jpg", "width": 800, "height": 800}]
    return {
        "fsq_id": fsq_id,
        "name": name,
        "categories": [{"id": category, "name": "Hotel"}],
        "geocodes": {"main": {"latitude": 3.848, "longitude": 11.502}},
        "location": {"address": "1 Main St", "locality": "Yaoundé"},
        "price": price,
        "photos": photos,
    }


class TestZeroPhotoExclusion:
    def test_venue_without_photo_is_excluded(self):
        """A venue with zero photos must NOT be stored (Step 3A)."""
        venue = _venue("fsq_1", "No Photo Hotel", has_photo=False)
        assert fs._normalize_venue(venue) is None

    def test_venue_with_photo_is_kept(self):
        """A venue with at least one photo must be kept."""
        venue = _venue("fsq_2", "Hilton Yaoundé", has_photo=True)
        dest = fs._normalize_venue(venue)
        assert dest is not None
        assert dest["fsq_id"] == "fsq_2"
        assert dest["image_source"] == "foursquare"
        assert len(dest["images"]) >= 1
        assert dest["category"] == "accommodation"


class TestImageUniqueness:
    def test_no_duplicate_images_across_venues(self):
        """Different venues must not share a photo URL."""
        v1 = _venue("fsq_10", "Hotel A", has_photo=True)
        v2 = _venue("fsq_11", "Hotel B", has_photo=True)
        d1 = fs._normalize_venue(v1)
        d2 = fs._normalize_venue(v2)
        urls = [d1["image"], d2["image"]]
        assert len(urls) == len(set(urls))

    def test_deduplicate_global_images_removes_dupes(self):
        """The safety-net dedup must keep photo URLs unique."""
        v = _venue("fsq_20", "Shared Photo Hotel", has_photo=True)
        d = fs._normalize_venue(v)
        item1 = dict(d)
        item2 = dict(d)  # same image URL
        items = [item1, item2]
        fs._deduplicate_global_images(items)
        # Only one of the two items retains the image.
        with_images = [it for it in items if it.get("image")]
        assert len(with_images) == 1


class TestNormalizeVenue:
    def test_category_mapping(self):
        """Foursquare category IDs map to our internal tags."""
        venue = _venue("fsq_30", "Museum", has_photo=True, category="10016")
        dest = fs._normalize_venue(venue)
        assert dest["category"] == "culture"

    def test_price_tier_to_cost(self):
        """Price tier maps to a XAF cost."""
        venue = _venue("fsq_31", "Budget Hotel", has_photo=True, price=1)
        dest = fs._normalize_venue(venue)
        assert dest["cost"] == 5000

    def test_junk_name_rejected(self):
        """Generic/junk names are not stored."""
        venue = _venue("fsq_32", "Hotel", has_photo=True)
        assert fs._normalize_venue(venue) is None
