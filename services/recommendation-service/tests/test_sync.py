"""Tests for overpass_sync.py"""
import pytest
from app.overpass_sync import _normalize_image_url, deduplicate_and_sync, _minimize_placeholder_reuse

def test_normalize_wikimedia_urls():
    """Test that Wikimedia Commons thumbnail URLs are normalized to the original file."""
    urls = [
        # Standard URL
        "https://upload.wikimedia.org/wikipedia/commons/f/f2/Stade_Omnisports_Ahmadou_Ahidjo_Yaound%C3%A9_01.jpg",
        # URL with thumbnail path
        "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/Stade_Omnisports_Ahmadou_Ahidjo_Yaound%C3%A9_01.jpg/800px-Stade_Omnisports_Ahmadou_Ahidjo_Yaound%C3%A9_01.jpg",
        # Different thumbnail size
        "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/Stade_Omnisports_Ahmadou_Ahidjo_Yaound%C3%A9_01.jpg/1200px-Stade_Omnisports_Ahmadou_Ahidjo_Yaound%C3%A9_01.jpg",
        # HTTP instead of HTTPS
        "http://upload.wikimedia.org/wikipedia/commons/f/f2/Stade_Omnisports_Ahmadou_Ahidjo_Yaound%C3%A9_01.jpg",
        # With query string
        "https://upload.wikimedia.org/wikipedia/commons/f/f2/Stade_Omnisports_Ahmadou_Ahidjo_Yaound%C3%A9_01.jpg?width=100",
        # Trailing slash
        "https://upload.wikimedia.org/wikipedia/commons/f/f2/Stade_Omnisports_Ahmadou_Ahidjo_Yaound%C3%A9_01.jpg/",
    ]
    
    expected = "https://upload.wikimedia.org/wikipedia/commons/f/f2/Stade_Omnisports_Ahmadou_Ahidjo_Yaound%C3%A9_01.jpg"

    normalized_urls = {_normalize_image_url(u) for u in urls}
    assert len(normalized_urls) == 1
    assert normalized_urls.pop() == expected

def test_normalize_other_urls():
    """Test that normalization works for non-wikimedia URLs.

    Canonical form: https forced, www. stripped, query string removed.
    """
    url = "http://www.example.com/path/to/image.png?param=1&param=2"
    expected = "https://example.com/path/to/image.png"
    assert _normalize_image_url(url) == expected

def test_within_gallery_deduplication():
    """Test that a destination with duplicate images in its gallery gets deduplicated."""
    # This test will be implemented after the main logic is refactored.
    pass

def test_cross_destination_placeholder_deduplication():
    """Test that placeholders are distributed and not clumped on one image."""
    # This test will be implemented after the placeholder logic is refactored.
    pass
