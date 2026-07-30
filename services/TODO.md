# Phase 2 — Microservices Migration TODO

## Step 1 ✅ Folder structure created
## Step 2 ✅ Database technology chosen (SQLite per service)
## Step 3 ✅ User Service built (register, login, JWT)
## Step 4 ✅ Itinerary Service built (CRUD, user-scoped)
## Step 5 ✅ Recommendation Service built (Overpass + Wikidata + Ratings + XAF currency)
## Step 6 ✅ API Gateway built (proxy router)
## Step 7 ✅ Docker Compose wired (4 services + 3 DBs on shared network)
## Step 8 ✅ Integration tests (gateway tests)
## Step 9 ✅ Frontend changes (images removed, rating UI, XAF currency display)
## Step 10 ⬜ Verify and test end-to-end

## Summary

**Final services structure:**
```
services/
├── user-service/              # Port 5001 — auth, users, JWT
├── itinerary-service/         # Port 5002 — itineraries CRUD
├── recommendation-service/    # Port 5003 — Overpass destinations, ratings, recs
├── api-gateway/               # Port 5000 — single entry point, pure proxy
└── docker-compose.yml         # All services on shared network
```

**Database:** SQLite per service (3 separate DBs, no cross-service access)

**Data migration:** JSON data from backend/data/ migrated to SQLite at startup

**Overpass integration:**
- Queries Overpass API for real Yaoundé POIs (tourism, amenity, leisure tags)
- Wikidata/Wikimedia images with verification (fallback to category placeholders)
- Cached in SQLite with last_synced_at timestamp
- Handles Overpass outages gracefully (returns cached data)

**Ratings:** POST /destinations/<id>/rating (JWT, 1-5, upsert per user)
**Currency:** All costs stored/displayed as XAF/FCFA
**Images:** Destinations/Home/Recommendations local assets deleted, auth assets preserved
**Recommendations:** Remains empty/placeholder as specified
**Favorites:** Not built (out of scope)
