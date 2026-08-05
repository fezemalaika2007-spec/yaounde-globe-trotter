# Recommendation Service

Provides destination discovery (OpenStreetMap Overpass sync), image fetching
(Wikidata / Wikimedia Commons), and the recommendation engine for the
GlobeTrotter Yaoundé travel assistant.

## Running the service

```bash
python -m app.main
# or
python run_sync.py        # manual sync runner
```

## Running the tests

The recommendation service has its own pytest suite covering:

- **Normalization** (`tests/test_normalization.py`) — OSM element filtering,
  junk-name/description rejection, long-description generation, and robust
  image-URL normalization.
- **Sync & deduplication** (`tests/test_sync.py`) — Wikimedia URL
  normalization across thumbnail sizes / http-https / query params.
- **Recommendation engine** (`tests/test_recommendations.py`) — category,
  favorite, popularity and quality scoring, diversity-aware selection, and
  the sectioned engine (Top Rated / Popular / Newly Added / category).
- **No-duplicate images** (`tests/test_no_duplicate_real_images.py`) — **the
  app-wide duplicate-image rule**: asserts no normalized image URL appears
  more than once across the whole destinations dataset (real AND placeholder),
  and no gallery contains a duplicate.

Run the full suite:

```bash
cd services/recommendation-service
python -m pytest tests/ -q
```

Run just the no-duplicate-image tests:

```bash
python -m pytest tests/test_no_duplicate_real_images.py -q
```

## Test command summary

| What                      | Command                                         |
|---------------------------|-------------------------------------------------|
| Full recommendation suite | `python -m pytest tests/ -q`                    |
| No-duplicate image rule   | `python -m pytest tests/test_no_duplicate_real_images.py -q` |

> These tests are part of the permanent app-wide suite. Any change to
> destination/image/recommendation logic must keep them green.
