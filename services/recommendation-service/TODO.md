# Yaounde Globe Trotter — Migration TODO

## Phase 1 — Foursquare Migration (previous task, in progress)
- [x] Create `app/foursquare_sync.py` (Foursquare Places API provider)
- [x] Replace Overpass/Wikidata/Wikimedia pipeline with Foursquare provider
- [x] Exclude venues with zero photos (Step 3A) — no placeholder fallback
- [x] Global no-duplicate-image safety net
- [x] Deduplicate by `fsq_id` and upsert to DB
- [x] Update routes, main, run_sync to use Foursquare
- [x] Categorized recommendations (most_popular, highly_rated, recently_added, less_costly, food_markets, nature_parks)
- [x] Update frontend api_service + recommendations_screen for named sections
- [x] Update unit tests to mock Foursquare (test_sync, test_normalization, test_foursquare_sync)
- [x] Fix `_deduplicate_global_images` / `deduplicate_and_sync` DB access (psycopg2)
- [x] Fix `models.get_connection` (remove sqlite `row_factory`)
- [ ] Run live Foursquare sync — BLOCKED: API key returns 410 (invalid/revoked)

## Phase 2 — Online PostgreSQL Migration (mostly done)
- [x] Migrate recommendation-service models to psycopg2 / DATABASE_URL
- [x] Migrate user-service models to psycopg2 / DATABASE_URL
- [x] Migrate itinerary-service models to psycopg2 / DATABASE_URL
- [x] Verify all 3 services connect to Neon PostgreSQL
- [x] Update requirements.txt (psycopg2-binary 2.9.10, python-dotenv)
- [x] Update docker-compose.yml to use DATABASE_URL (remove local SQLite volumes)
- [ ] Remove old SQLite `.db` files entirely
- [x] Create `.env.example`

## Phase 3 — Cleanup obsolete files
- [ ] Delete old SQLite DB files (recommendations.db, users.db, itineraries.db)
- [ ] Delete old Overpass/Wikidata helper tools/scripts
- [ ] Delete empty migrations/ dir
- [ ] Delete stale top-level scripts (check_db.py, destinations.json)

## Phase 4 — Authentication: Google Login + Sign-up verification
- [ ] Add `email`, `is_verified`, `verification_code` columns to users table
- [ ] Add `POST /auth/google` endpoint (verify Google ID token)
- [ ] Add `POST /register` to create unverified user + verification code
- [ ] Add `POST /verify` endpoint to confirm email
- [ ] Add `google_sign_in` to Flutter pubspec
- [ ] Add "Continue with Google" button to login screen
- [ ] Add email field + verification to register screen
- [ ] Wire AuthProvider for Google login + verification flow

## Phase 5 — Verification & warnings
- [ ] Run recommendation-service test suite
- [ ] Run `flutter analyze` and fix warnings
- [ ] Provide Neon DB console link
