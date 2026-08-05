"""recommendation-service/recommendations.py

Recommendation scoring engine.

Scores all destinations for the logged-in user by combining:
  * explicit preferences collected at registration (food, nature, culture, ...)
  * the user's favorite destinations (implicit positive signal)
  * popularity (average rating & rating count)
  * quality/relevance signals (images, description length, price level)

The result list is diversity-aware: it tries not to flood the user with a
single category, so the top picks cover several different kinds of places.
"""
import os
import logging
import requests

logger = logging.getLogger(__name__)

USER_SERVICE_URL = os.environ.get(
    "USER_SERVICE_URL", "http://user-service:5001"
)

# Preference groups map the tags collected at registration to destination
# categories that we use internally (category values produced by overpass_sync).
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


def _fetch_user_preferences(username, token):
    """Fetch preferences + favorites for *username* from the User Service.

    Uses the internal JWT-protected endpoint added to the user service.
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
        # avg is 1-5, normalise to 0..0.8
        score += (float(avg) / 5.0) * 0.8
    if count:
        # a handful of ratings is meaningful, cap at ~0.7
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
    """Return a diversity-aware, scored list of recommendations.

    Args:
        username: currently not needed for scoring but kept for future use.
        destinations: list of destination dicts (from DB).
        token: JWT of the user (used to fetch preferences/favorites).
        limit: max number of recommendations to return.

    Returns:
        List of destination dicts, best first.
    """
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

    # Sort best first.
    scored.sort(key=lambda pair: pair[0], reverse=True)

    # Diversity pass: take the top scorer, then prefer entries from a category
    # we haven't used yet, while still respecting overall score ordering.
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
            # All remaining categories are already represented — just take the best.
            best_idx = 0
            best_cat_seen = (remaining[0][1].get("category") or "attraction").lower()

        _, best_dest = remaining.pop(best_idx)
        selected.append(best_dest)
        seen_categories.add(best_cat_seen)

    return selected


# ---------------------------------------------------------------------------
# Structured, section-based recommendations (interim logic)
# ---------------------------------------------------------------------------
#
# Before we have enough per-user behavioural data, we present recommendations
# in recognizable, real sections (similar to how Airbnb / Booking.com surface
# "Popular homes", "Trending destinations", "Top experiences"):
#
#   - "Top Rated in Yaoundé"  -> highest average_rating with a rating_count
#                                minimum (avoid surfacing a place with one 5-star).
#   - "Popular Right Now"     -> most recent ratings / interactions (popularity).
#   - "Newly Added"           -> most recently synced destinations.
#   - Category sections       -> "Nature & Parks", "Food & Markets", etc.
#
# The response shape is fixed so this heuristic engine can later be swapped for
# a real personalization engine (search history, favourites, behaviour) without
# changing the API contract.


# Minimum rating count before a place counts as "top rated".
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


def _popular_right_now(destinations, limit):
    """Most rated / interacted destinations as a simple popularity signal."""
    scored = []
    for d in destinations:
        count = d.get("rating_count") or 0
        avg = float(d.get("average_rating") or 0.0)
        # Heuristic: popularity signal weights recent interactions (count) and
        # a reasonable rating. A place with many ratings ranks above a single 5-star.
        score = count + (avg * count * 0.5)
        scored.append((score, d))
    scored.sort(key=lambda pair: pair[0], reverse=True)
    return [d for _, d in scored[:limit] if _popularity_score(d) > 0]


def _newly_added(destinations, limit):
    """Most recently synced destinations the user likely hasn't seen yet."""
    def _synced_ts(d):
        raw = d.get("last_synced_at") or ""
        return raw
    eligible = [d for d in destinations if d.get("last_synced_at")]
    eligible.sort(key=_synced_ts, reverse=True)
    return eligible[:limit]


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


def get_sectioned_recommendations(destinations, token="", limit=5):
    """Return a structured, section-based set of recommendations.

    This is the interim heuristic engine. It returns a fixed shape:
        {
          "sections": [
             {"title": ..., "type": ..., "items": [destination, ...]},
             ...
          ]
        }

    Both the personalised [get_recommendations] and this sectioned engine return
    destinations in the same destination-dict shape, so swapping the engine later
    (real personalization) will not change the API contract.
    """
    # Only ever show destinations that have a real image — placeholders should
    # not dominate the curated recommendation sections.
    with_images = [
        d for d in destinations
        if d.get("image_source") not in ("placeholder", "") and (d.get("image") or "")
    ]
    # If there are very few real images, fall back to any destination with a
    # meaningful description so the page is never empty.
    pool = with_images if len(with_images) >= 4 else destinations

    sections = []

    top = _top_rated(pool, limit)
    if top:
        sections.append({"title": "Top Rated in Yaoundé", "type": "top_rated", "items": top})

    popular = _popular_right_now(pool, limit)
    if popular:
        sections.append({"title": "Popular Right Now", "type": "popular", "items": popular})

    new = _newly_added(pool, limit)
    if new:
        sections.append({"title": "Newly Added", "type": "new_added", "items": new})

    # Category sections — only include categories that have real, image-bearing
    # destinations so the page has genuine structure and variety.
    for cat, title in CATEGORY_SECTION_TITLES.items():
        items = _category_section(pool, cat, limit)
        if items:
            sections.append({"title": title, "type": f"category_{cat}", "items": items})

    return {"sections": sections}

