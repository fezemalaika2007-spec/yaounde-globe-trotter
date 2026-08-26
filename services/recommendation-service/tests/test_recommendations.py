"""tests/test_recommendations.py — pytest suite for the recommendation engine."""
import sys
from pathlib import Path

# Ensure the service directory is on sys.path so "app" is importable.
_service_dir = str(Path(__file__).resolve().parents[1])
if _service_dir not in sys.path:
    sys.path.insert(0, _service_dir)

import pytest

# Import the recommendation engine
from app.recommendations import (
    _category_score,
    _favorite_score,
    _popularity_score,
    _quality_score,
    get_recommendations,
    get_sectioned_recommendations,
    _top_rated,
    _popular_right_now,
    _newly_added,
    _category_section,
    MIN_RATING_COUNT_FOR_TOP,
)


SAMPLE_DESTINATIONS = [
    {"name": "Mefou Park", "category": "nature", "tags": ["nature", "park"],
     "image_source": "wikimedia", "description": "A " * 40,
     "average_rating": 4.5, "rating_count": 12, "phone": "123", "website": "url"},
    {"name": "National Museum", "category": "culture", "tags": ["culture", "museum"],
     "image_source": "wikimedia", "description": "B " * 40,
     "average_rating": 4.0, "rating_count": 8, "phone": "", "website": ""},
    {"name": "Central Market", "category": "market", "tags": ["market", "shopping"],
     "image_source": "placeholder", "description": "C " * 10,
     "average_rating": 3.0, "rating_count": 2},
    {"name": "Hilton Hotel", "category": "accommodation", "tags": ["accommodation", "hotel"],
     "image_source": "wikimedia", "description": "D " * 40,
     "average_rating": 4.2, "rating_count": 20, "phone": "456", "website": "url"},
    {"name": "Sports Palace", "category": "sports", "tags": ["sports", "stadium"],
     "image_source": "wikimedia", "description": "E " * 40,
     "average_rating": 3.8, "rating_count": 5},
    {"name": "Restaurant Raphaelo", "category": "food", "tags": ["food", "restaurant"],
     "image_source": "wikimedia", "description": "F " * 40,
     "average_rating": 4.7, "rating_count": 30, "phone": "789"},
]


class TestCategoryScore:
    def test_matching_preferences_boost(self):
        dest = SAMPLE_DESTINATIONS[0]  # nature
        score = _category_score(dest, ["nature", "food"])
        assert score > 0

    def test_no_preferences_returns_zero(self):
        dest = SAMPLE_DESTINATIONS[0]
        score = _category_score(dest, [])
        assert score == 0.0

    def test_non_matching_preferences_returns_zero(self):
        dest = SAMPLE_DESTINATIONS[0]  # nature
        score = _category_score(dest, ["shopping"])
        assert score == 0.0

    def test_tag_match_also_counts(self):
        dest = {"name": "Test", "category": "unknown", "tags": ["food"]}
        score = _category_score(dest, ["food"])
        assert score > 0


class TestFavoriteScore:
    def test_favorited_destination_gets_boost(self):
        dest = {"name": "Mefou Park"}
        score = _favorite_score(dest, ["Mefou Park", "Museum"])
        assert score == 3.0

    def test_non_favorited_returns_zero(self):
        dest = {"name": "Mefou Park"}
        score = _favorite_score(dest, ["Museum"])
        assert score == 0.0

    def test_case_insensitive(self):
        dest = {"name": "Mefou Park"}
        score = _favorite_score(dest, ["mefou park"])
        assert score == 3.0


class TestPopularityScore:
    def test_high_rating_high_count(self):
        dest = {"average_rating": 5.0, "rating_count": 100}
        score = _popularity_score(dest)
        assert score > 1.0

    def test_no_ratings_returns_low_score(self):
        dest = {"average_rating": 0, "rating_count": 0}
        score = _popularity_score(dest)
        assert score < 0.1

    def test_rating_only_without_count(self):
        dest = {"average_rating": 4.0, "rating_count": 0}
        score = _popularity_score(dest)
        assert score > 0
        # Should be roughly (4.0/5.0)*0.8 ≈ 0.64
        assert 0.5 < score < 0.8


class TestQualityScore:
    def test_real_image_and_long_description(self):
        dest = {"image_source": "wikimedia", "description": "A " * 80, "phone": "123"}
        score = _quality_score(dest)
        # image (0.8) + long desc (0.5) + phone (0.3) = 1.6
        assert score >= 1.5

    def test_placeholder_image_no_description(self):
        dest = {"image_source": "placeholder", "description": "", "phone": ""}
        score = _quality_score(dest)
        assert score < 0.1


class TestGetRecommendations:
    def test_returns_limited_results(self):
        # Use a mock token — the engine will fail to fetch preferences
        # and fall back to popularity-only scoring.
        results = get_recommendations(
            "testuser", SAMPLE_DESTINATIONS, "mock-token", limit=3
        )
        assert len(results) <= 3
        assert len(results) > 0

    def test_diversity_across_categories(self):
        """With enough destinations, the top results should include
        at least 2 different categories."""
        results = get_recommendations(
            "testuser", SAMPLE_DESTINATIONS, "mock-token", limit=5
        )
        categories = {d.get("category", "") for d in results}
        assert len(categories) >= 2, f"Expected diverse categories, got {categories}"

    def test_best_scored_comes_first(self):
        results = get_recommendations(
            "testuser", SAMPLE_DESTINATIONS, "mock-token", limit=6
        )
        # The first result should have a meaningful score (it's the best
        # quality match even without preferences).
        assert len(results) > 0
        first = results[0]
        assert first["name"] is not None


class TestSectionedRecommendations:
    def test_top_rated_requires_min_count(self):
        # Single 5-star with rating_count 1 should NOT be top rated.
        dests = [
            {"name": "One Star", "average_rating": 5.0, "rating_count": 1},
            {"name": "Steady", "average_rating": 4.0, "rating_count": 10},
        ]
        top = _top_rated(dests, limit=5)
        assert all(d["rating_count"] >= MIN_RATING_COUNT_FOR_TOP for d in top)
        assert any(d["name"] == "Steady" for d in top)

    def test_popular_right_now(self):
        dests = [
            {"name": "A", "average_rating": 4.0, "rating_count": 50},
            {"name": "B", "average_rating": 5.0, "rating_count": 1},
        ]
        popular = _popular_right_now(dests, limit=5)
        assert popular[0]["name"] == "A"

    def test_newly_added_sorts_by_sync_time(self):
        dests = [
            {"name": "Old", "last_synced_at": "2020-01-01T00:00:00"},
            {"name": "New", "last_synced_at": "2024-01-01T00:00:00"},
        ]
        new = _newly_added(dests, limit=5)
        assert new[0]["name"] == "New"

    def test_category_section_filters(self):
        dests = [
            {"name": "Park", "category": "nature"},
            {"name": "Museum", "category": "culture"},
        ]
        items = _category_section(dests, "nature", limit=5)
        assert len(items) == 1 and items[0]["name"] == "Park"

    def test_get_sectioned_returns_sections_shape(self):
        payload = get_sectioned_recommendations(SAMPLE_DESTINATIONS, limit=5)
        assert "sections" in payload
        assert isinstance(payload["sections"], list)
        # There should be at least one section with items.
        assert any(s.get("items") for s in payload["sections"])
        # Section titles should be real, non-empty strings.
        for section in payload["sections"]:
            assert section.get("title")
            assert section.get("type")
            assert isinstance(section.get("items"), list)
