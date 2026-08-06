"""Tests for foursquare_sync.py"""
import pytest
from app.foursquare_sync import _normalize_image_url, deduplicate_and_sync, _deduplicate_global_images


def test_normalize_foursquare_urls():
    """Test that Foursquare photo URLs are normalized consistently."""
    urls = [
        # Standard URL
        "https://fastly.4sqi.net/img/general/800x800/ABC123_hash.jpg",
        # HTTP instead of HTTPS (should be same after normalization)
        "http://fastly.4sqi.net/img/general/800x800/ABC123_hash.jpg",
        # Trailing slash
        "https://fastly.4sqi.net/img/general/800x800/ABC123_hash.jpg/",
    ]

    expected = "https://fastly.4sqi.net/img/general/800x800/ABC123_hash.jpg"

    normalized_urls = {_normalize_image_url(u) for u in urls}
    assert len(normalized_urls) == 1
    assert normalized_urls.pop() == expected


def test_normalize_other_urls():
    """Test that normalization works for non-Foursquare URLs.

    Canonical form: https forced, www. stripped, query string removed.
    """
    url = "http://www.example.com/path/to/image.png?param=1&param=2"
    expected = "https://example.com/path/to/image.png"
    assert _normalize_image_url(url) == expected


def test_deduplicate_global_images_keeps_urls_unique():
    """Test that the global image dedup keeps each URL used once."""
    item_a = {
        "fsq_id": "a",
        "image": "https://fastly.4sqi.net/img/general/800x800/AAAA.jpg",
        "images": ["https://fastly.4sqi.net/img/general/800x800/AAAA.jpg"],
        "image_source": "foursquare",
    }
    item_b = {
        "fsq_id": "b",
        "image": "https://fastly.4sqi.net/img/general/800x800/AAAA.jpg",
        "images": ["https://fastly.4sqi.net/img/general/800x800/AAAA.jpg"],
        "image_source": "foursquare",
    }
    items = [item_a, item_b]
    _deduplicate_global_images(items)
    # After dedup, only one item should have the image.
    with_images = [it for it in items if it.get("image")]
    assert len(with_images) == 1
