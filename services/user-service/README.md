# User Service

Manages user accounts, authentication (JWT), preferences and favorites for
the GlobeTrotter Yaoundé travel assistant.

## Database

The User Service connects to its own online PostgreSQL database, configured
via the `DATABASE_URL` environment variable (never hardcoded, never committed).
Tables are created automatically on first run via `init_db()`.

## Running the service

```bash
python -m app.main
```

## Running the tests

The user service has its own pytest suite (`tests/test_user_service.py`)
covering registration, login, duplicate-username handling, missing-field
validation, internal preferences retrieval, and CORS headers.

Run the full suite:

```bash
cd services/user-service
python -m pytest tests/ -q
```

## Test command summary

| What                | Command                      |
|---------------------|------------------------------|
| Full user suite     | `python -m pytest tests/ -q` |

> Part of the permanent app-wide suite. Keep green on any auth/user change.
