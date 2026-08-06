# Recommendation Service

Provides destination discovery via the **Foursquare Places API** (with photos
already attached to each venue), the no-duplicate-image safety net, the
categorized recommendation engine, and ratings for the GlobeTrotter Yaoundé
travel assistant.

## Data source

All destinations and their photos come from Foursquare:

- **Discovery** — queries Foursquare for venues around Yaoundé, Cameroon
  (lat 3.848, lon 11.502) across the travel-relevant category taxonomy
  (restaurants, hotels, museums, parks, markets, attractions, etc.).
- **Photos** — Foursquare returns photo URLs directly tied to each specific
  venue ID, so there is no separate matching or fallback step and no shared
  image pool that can cause duplicate-image bugs.
- **No placeholders** — venues with **zero photos are excluded entirely**
  (Step 3A). The app only ever contains destinations that have at least one
  real Foursquare photo.
- **No duplicates** — a global safety-net deduplication check ensures no
  single photo URL is assigned to more than one destination.

## Configuration

Requires the following environment variables (never hardcoded):

| Variable | Purpose |
|----------|---------|
| `FOURSQUARE_API_KEY` | Foursquare Places API key (or `FOURSQUARE_CLIENT_ID` + `FOURSQUARE_CLIENT_SECRET` for the v2 legacy API) |
| `DATABASE_URL` | PostgreSQL connection string for the online database |
| `SECRET_KEY` | Flask secret key |
| `USER_SERVICE_URL` | Internal URL of the user service (default `http://user-service:5001`) |

## Running the service

```bash
python -m app.main
# or
python run_sync.py        # manual sync runner
```

## Running the tests

The recommendation service has its own pytest suite covering:

- **Foursquare sync** (`tests/test_foursquare_sync.py`) — mocks the Foursquare
  API and verifies venues with zero photos are excluded, photo URLs stay
  unique, and venues with photos are normalized/kept.
- **Normalization** (`tests/test_normalization.py`) — junk-name rejection and
  robust image-URL normalization.
- **Sync & deduplication** (`tests/test_sync.py`) — Foursquare URL
  normalization and the global image-dedup safety net.
- **Recommendation engine** (`tests/test_recommendations.py`) — category,
  favorite, popularity and quality scoring, diversity-aware selection, and the
  categorized sectioned engine (Most Popular / Highly Rated / Recently Added /
  Less Costly / category).
- **No-duplicate images** (`tests/test_no_duplicate_real_images.py`) — the
  app-wide duplicate-image rule: asserts no normalized image URL appears more
  than once across the whole destinations dataset. Skips gracefully when
  `DATABASE_URL` is not set.

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
