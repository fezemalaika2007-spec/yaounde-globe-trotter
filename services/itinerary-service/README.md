# Itinerary Service

Manages travel itineraries for the GlobeTrotter Yaoundé travel assistant:
create, list, scoped to the authenticated user, with JWT auth.

## Database

The Itinerary Service connects to its own online PostgreSQL database,
configured via the `DATABASE_URL` environment variable (never hardcoded,
never committed). Tables are created automatically on first run via
`init_db()`.

## Running the service

```bash
python -m app.main
```

## Running the tests

The itinerary service has its own pytest suite (`tests/test_itinerary_service.py`)
covering auth guards, creation validation, per-user scoping, and internal
by-user routes.

Run the full suite:

```bash
cd services/itinerary-service
python -m pytest tests/ -q
```

## Test command summary

| What                    | Command                      |
|-------------------------|------------------------------|
| Full itinerary suite    | `python -m pytest tests/ -q` |

> Part of the permanent app-wide suite. Keep green on any itinerary change.
