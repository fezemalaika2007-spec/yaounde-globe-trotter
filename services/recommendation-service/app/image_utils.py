"""recommendation-service/image_utils.py

Image URL helpers for the Recommendation Service.

The old curated placeholder pool (_YaoundeImages) and the Wikidata/Wikimedia
image-fetching pipeline have been REMOVED entirely. The app now sources all
destination photos directly from the Foursquare Places API, where each photo
is already attached to a specific venue — so there is no shared image pool
that can run out and cause duplicate-image bugs.

This module now only keeps the URL-normalization helper used for the global
no-duplicate-image safety net.
"""
import logging
import re
from urllib.parse import urlparse, unquote, quote

logger = logging.getLogger(__name__)


def normalize_image_url(url: str) -> str:
    """Normalize an image URL to a canonical form for robust deduplication.

    Rules applied (in order):
    - Enforces HTTPS (http://foo -> https://foo, so http and https are the same)
    - Removes 'www.' prefix from the host
    - Lowercases scheme and host
    - Removes trailing slashes
    - For Wikimedia Commons URLs, removes thumbnail paths to get the original
      image URL (kept for backward-compat with any already-stored data).
    """
    if not url:
        return ""
    try:
        p = urlparse(url)
        scheme = "https"
        netloc = (p.netloc or "").lower()
        if "@" in netloc:
            netloc = netloc.rsplit("@", 1)[-1]
        if netloc.startswith("www."):
            netloc = netloc[4:]

        path = p.path

        # Wikimedia Commons thumbnails: /thumb/<a>/<ab>/<File>/<NNNpx-<File>>
        # -> /<a>/<ab>/<File>
        if "upload.wikimedia.org" in netloc:
            path = re.sub(r'/thumb/(.+?)/[^/]+$', r'/\1', path)

        unquoted = unquote(path)
        canonical_path = quote(unquoted, safe="/:,. _-()'")
        canonical_path = canonical_path.rstrip("/")

        return f"{scheme}://{netloc}{canonical_path}"
    except Exception as e:
        logger.warning(f"URL normalization failed for '{url}': {e}")
        return url.strip().lower().rstrip("/")


# Backward-compatible alias used by the tests.
def _normalize_image_url(url: str) -> str:
    """Alias for [normalize_image_url]."""
    return normalize_image_url(url)
