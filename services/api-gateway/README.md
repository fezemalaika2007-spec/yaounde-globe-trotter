# API Gateway

Single public entry point for the GlobeTrotter Yaoundé travel assistant. It
contains **no business logic** — it proxies requests to the User, Itinerary,
and Recommendation services. Behind the gateway, each backend service owns its
own online PostgreSQL database (configured via `DATABASE_URL`), but the
gateway itself only routes requests and is database-agnostic.

## Running the service

```bash
python -m app.main
```

## Running the tests

The API Gateway has two pytest suites:

1. **Proxy routing** (`tests/test_api_gateway.py`) — verifies the gateway
   forwards each route to the correct backend service with the right method,
   headers, query params, and JSON body; health check; and 503 on
   unreachable services.
2. **Consolidated integration journey** (`tests/test_integration_journey.py`)
   — runs the **full user journey through the gateway**:
   register → login → search/filter destinations → view a destination →
   submit a rating → view recommendations → create an itinerary → list
   itineraries. It mocks the backend microservices to respond as real
   services would, and asserts the gateway orchestrates the whole flow
   correctly.

Run the full suite (both files):

```bash
cd services/api-gateway
python -m pytest tests/ -q
```

Run just the integration journey:

```bash
python -m pytest tests/test_integration_journey.py -q
```

## Test command summary

| What                    | Command                                        |
|-------------------------|------------------------------------------------|
| Full gateway suite      | `python -m pytest tests/ -q`                   |
| Integration journey     | `python -m pytest tests/test_integration_journey.py -q` |

> Part of the permanent app-wide suite. Keep green on any routing change.
