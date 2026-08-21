"""recommendation-service/recommendations.py

Categorized recommendation engine.

Returns recommendations organized into clear, human-recognizable categories,
similar to how real travel/booking apps structure their home or
recommendations feed:

  * "Most Popular"  — destinations with the highest rating_count (most-rated).
  * "Highly Rated"  — destinations with the highest average_rating, subject to
                      a minimum rating_count threshold.
  * "Recently Added" — destinations most recently synced/added to the DB.
  * "Less Costly"   — destinations with the lowest known cost (XAF), excluding
                      destinations with unknown/null cost.
  * Extra tag sections — "Food & Markets", "Nature & Parks" when the data
                      supports them.

The response shape is a single object with named keys (most_popular,
highly_rated, recently_added, less_costly, ...), each an array of destinations,
so the frontend can render each as its own horizontal section.
"""
import os
import logging
import requests

logger = logging.getLogger(__name__)

USER_SERVICE_URL = os.environ.get(
    "USER_SERVICE_URL", "http://user-service:5001"
)

# Preference groups map the tags collected at registration to destination
# categories that we use internally.
PREFERENCE_TO_CATEGORY = {
    "food": {"food", "market"},
    "nature": {"nature", "sports"},
    "culture": {"culture", "attraction", "market"},
    "accommodation": {"accommodation"},
    "shopping": {"market", "finance", "services"},
    "health": {"health", "services"},
    "transport": {"transport", "services"},
    "business": {"business", "services"},
    "finance": {"finance"},
    "sports": {"sports", "nature"},
    "history": {"culture", "attraction"},
    "outdoor": {"nature", "sports", "attraction"},
    "nightlife": set(),  # deliberately empty — we filter out bars/nightclubs
}

# Minimum rating count before a place counts as "Highly Rated".
MIN_RATING_COUNT_FOR_TOP = 3

# Human-friendly section titles mapped from our internal category labels.
CATEGORY_SECTION_TITLES = {
    "nature": "Nature & Parks",
    "food": "Food & Dining",
    "market": "Markets & Shopping",
    "culture": "Culture & Museums",
    "accommodation": "Places to Stay",
    "sports": "Sports & Recreation",
    "attraction": "Top Attractions",
    "health": "Health & Wellness",
    "transport": "Getting Around",
    "services": "Useful Services",
    "business": "Business & Events",
    "finance": "Banking & Finance",
}


def _fetch_user_preferences(username, token):
    """Fetch preferences + favorites for *username* from the User Service.

    Returns (preferences_list, favorites_list). Failure is non-fatal and
    returns empty lists so the app still recommends popular places.
    """
    try:
        response = requests.get(
            f"{USER_SERVICE_URL}/internal/users/preferences",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        if response.ok:
            data = response.json()
            return (
                data.get("preferences", []) or [],
                data.get("favorites", []) or [],
            )
    except Exception as e:
        logger.warning(f"Failed to fetch preferences from user-service: {e}")
    return [], []


def _category_score(destination, preferences):
    """Score based on how well the destination matches the user's preferences."""
    if not preferences:
        return 0.0
    category = (destination.get("category") or "").lower()
    tags = [t.lower() for t in (destination.get("tags") or [])]
    score = 0.0
    for pref in preferences:
        pref_key = (pref or "").lower().strip()
        categories = PREFERENCE_TO_CATEGORY.get(pref_key, {pref_key})
        if category in categories:
            score += 2.0
        if any(tag in categories for tag in tags):
            score += 1.5
    return score


def _favorite_score(destination, favorites):
    """Boost destinations the user already favorited (implicit interest)."""
    if not favorites:
        return 0.0
    name = (destination.get("name") or "").lower().strip()
    if name in {f.lower().strip() for f in favorites}:
        return 3.0
    return 0.0


def _popularity_score(destination):
    """Score from average_rating and rating_count (normalized 0..~1.5)."""
    avg = destination.get("average_rating") or 0.0
    count = destination.get("rating_count") or 0
    score = 0.0
    if avg:
        score += (float(avg) / 5.0) * 0.8
    if count:
        score += min(0.7, float(count) / 10.0 * 0.7)
    return round(score, 3)


def _quality_score(destination):
    """Boost destinations with a real image and a rich description."""
    score = 0.0
    image_source = destination.get("image_source") or ""
    if image_source != "placeholder":
        score += 0.8
    description = (destination.get("description") or "").strip()
    if len(description) >= 120:
        score += 0.5
    elif len(description) >= 60:
        score += 0.3
    if destination.get("phone") or destination.get("website"):
        score += 0.3
    return round(score, 3)


def get_recommendations(username, destinations, token, limit=6):
    """Return a diversity-aware, scored list of recommendations."""
    preferences, favorites = _fetch_user_preferences(username, token)

    scored = []
    for dest in destinations:
        total = (
            _category_score(dest, preferences)
            + _favorite_score(dest, favorites)
            + _popularity_score(dest)
            + _quality_score(dest)
        )
        scored.append((total, dest))

    scored.sort(key=lambda pair: pair[0], reverse=True)

    selected = []
    seen_categories = set()
    remaining = list(scored)

    while remaining and len(selected) < limit:
        best_idx = 0
        best_cat_seen = None
        for i, (score, dest) in enumerate(remaining):
            cat = (dest.get("category") or "attraction").lower()
            if cat not in seen_categories:
                best_idx = i
                best_cat_seen = cat
                break
        if best_cat_seen is None:
            best_idx = 0
            best_cat_seen = (remaining[0][1].get("category") or "attraction").lower()

        _, best_dest = remaining.pop(best_idx)
        selected.append(best_dest)
        seen_categories.add(best_cat_seen)

    return selected


# ---------------------------------------------------------------------------
# Categorized, section-based recommendations
# ---------------------------------------------------------------------------

def _top_rated(destinations, limit):
    """Destinations with the highest average_rating and a meaningful count."""
    eligible = [
        d for d in destinations
        if (d.get("rating_count") or 0) >= MIN_RATING_COUNT_FOR_TOP
        and (d.get("average_rating") or 0) > 0
    ]
    eligible.sort(
        key=lambda d: (
            float(d.get("average_rating") or 0.0),
            d.get("rating_count") or 0,
        ),
        reverse=True,
    )
    return eligible[:limit]


def _most_popular(destinations, limit):
    """Destinations with the highest rating_count (most engagement)."""
    eligible = [d for d in destinations if (d.get("rating_count") or 0) > 0]
    eligible.sort(
        key=lambda d: d.get("rating_count") or 0,
        reverse=True,
    )
    return eligible[:limit]


def _highly_rated(destinations, limit):
    """Same as top-rated: highest average_rating with a minimum count."""
    return _top_rated(destinations, limit)


def _recently_added(destinations, limit):
    """Most recently synced destinations the user likely hasn't seen yet."""
    eligible = [d for d in destinations if d.get("last_synced_at")]
    eligible.sort(key=lambda d: d.get("last_synced_at") or "", reverse=True)
    return eligible[:limit]


def _less_costly(destinations, limit):
    """Destinations with the lowest known cost (XAF).

    Excludes destinations with unknown/null cost since they can't be ranked.
    """
    eligible = [d for d in destinations if d.get("cost") is not None]
    eligible.sort(key=lambda d: d.get("cost") or 0)
    return eligible[:limit]


def _popular_right_now(destinations, limit):
    """Most rated / interacted destinations as a simple popularity signal."""
    scored = []
    for d in destinations:
        count = d.get("rating_count") or 0
        avg = float(d.get("average_rating") or 0.0)
        score = count + (avg * count * 0.5)
        scored.append((score, d))
    scored.sort(key=lambda pair: pair[0], reverse=True)
    return [d for _, d in scored[:limit] if _popularity_score(d) > 0]


def _newly_added(destinations, limit):
    """Most recently synced destinations."""
    return _recently_added(destinations, limit)


def _category_section(destinations, category, limit):
    """Top items from a single destination category."""
    members = [d for d in destinations if (d.get("category") or "").lower() == category]
    members.sort(
        key=lambda d: (
            float(d.get("average_rating") or 0.0),
            d.get("rating_count") or 0,
            len((d.get("long_description") or d.get("description") or "").strip()),
        ),
        reverse=True,
    )
    return members[:limit]


def _tag_based_section(destinations, tag, limit):
    """Top items from a destination tag (e.g. 'food', 'nature')."""
    members = [
        d for d in destinations
        if tag in [t.lower() for t in (d.get("tags") or [])]
    ]
    members.sort(
        key=lambda d: (
            float(d.get("average_rating") or 0.0),
            d.get("rating_count") or 0,
        ),
        reverse=True,
    )
    return members[:limit]


def get_sectioned_recommendations(destinations, token="", limit=5):
    """Return categorized recommendations as named sections.

    Returns a dict with named keys:
        {
          "sections": [
             {"title": ..., "type": ..., "items": [destination, ...]},
             ...
          ]
        }

    Each named category (most_popular, highly_rated, recently_added,
    less_costly, ...) is also exposed as a top-level key mapping to the item
    list, so the frontend can render each as its own horizontal section.
    """
    # Only ever show destinations that have a real image.
    with_images = [
        d for d in destinations
        if (d.get("image_source") not in ("placeholder", "") and (d.get("image") or ""))
    ]
    pool = with_images if len(with_images) >= 4 else destinations

    sections = []
    payload = {}

    # 1. Most Popular (highest rating_count).
    most_popular = _most_popular(pool, limit)
    if most_popular:
        sections.append({"title": "Most Popular", "type": "most_popular", "items": most_popular})
        payload["most_popular"] = most_popular

    # 2. Highly Rated (highest average_rating with min count).
    highly_rated = _highly_rated(pool, limit)
    if highly_rated:
        sections.append({"title": "Highly Rated", "type": "highly_rated", "items": highly_rated})
        payload["highly_rated"] = highly_rated

    # 3. Recently Added (most recently synced).
    recently_added = _recently_added(pool, limit)
    if recently_added:
        sections.append({"title": "Recently Added", "type": "recently_added", "items": recently_added})
        payload["recently_added"] = recently_added

    # 4. Less Costly (lowest known cost, excluding null/unknown).
    less_costly = _less_costly(pool, limit)
    if less_costly:
        sections.append({"title": "Less Costly", "type": "less_costly", "items": less_costly})
        payload["less_costly"] = less_costly

    # 5. Extra tag-based sections (if data supports them).
    food_markets = _tag_based_section(pool, "food", limit)
    if len(food_markets) >= 2:
        sections.append({"title": "Food & Markets", "type": "food_markets", "items": food_markets})
        payload["food_markets"] = food_markets

    nature_parks = _tag_based_section(pool, "nature", limit)
    if len(nature_parks) >= 2:
        sections.append({"title": "Nature & Parks", "type": "nature_parks", "items": nature_parks})
        payload["nature_parks"] = nature_parks

    # 6. Category sections (only those with real image-bearing destinations).
    for cat, title in CATEGORY_SECTION_TITLES.items():
        items = _category_section(pool, cat, limit)
        if items:
            sections.append({"title": title, "type": f"category_{cat}", "items": items})

    payload["sections"] = sections
    return payload
