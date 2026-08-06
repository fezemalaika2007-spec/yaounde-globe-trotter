# Migration Plan — Foursquare + Online PostgreSQL + Categorized Recommendations

## Phase 1 — Foursquare migration (recommendation-service)
- [x] Create `app/foursquare_sync.py` (Foursquare provider, sync, search, dedup, zero-photo exclusion)
- [x] Rewrite `app/image_utils.py` (remove placeholder pool + Wikimedia; keep URL normalization)
- [x] Update `app/models.py` (fsq_id, PostgreSQL)
- [x] Update `app/routes.py` (imports, search, sync)
- [x] Update `app/main.py` (sync module reference)
- [x] Update `run_sync.py`
- [x] Update/add tests (mock Foursquare, zero-photo exclusion, no-duplicates)

## Phase 2 — Categorized recommendations (backend + frontend)
- [x] Update `app/recommendations.py` (Most Popular, Highly Rated, Recently Added, Less Costly, tag extras)
- [x] Update `app/routes.py` GET /recommendations shape
- [x] Update `frontend/lib/services/api_service.dart`
- [x] Update `frontend/lib/screens/recommendations_screen.dart`

## Phase 3 — Online PostgreSQL migration (all 3 services)
- [x] Update `recommendation-service` models to PostgreSQL (psycopg2, DATABASE_URL)
- [x] Update `user-service` models to PostgreSQL
- [x] Update `itinerary-service` models to PostgreSQL
- [x] Add migration (init_db creates tables)
- [x] Update requirements.txt (psycopg2-binary, python-dotenv)
- [x] Update docker-compose.yml (remove local volumes, add DATABASE_URL)
- [x] Add .env.example

## Phase 4 — Cleanup & verification
- [x] Delete old Overpass/Wikidata scripts and placeholder tools
- [ ] Run sync, report discovered/kept/excluded
- [ ] Run no-duplicate test, confirm passing
- [ ] Verify /destinations, search, filters, recommendations
- [ ] Verify all 3 services connect to online PostgreSQL
</content>
