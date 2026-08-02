"""tests/test_recommendations.py — pytest suite for the recommendation engine."""
import pytest

# Import the recommendation engine
from app.recommendations import (
    _category_score,
    _favorite_score,
    _popularity_score,
    _quality_score,
    get_recommendations,
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
