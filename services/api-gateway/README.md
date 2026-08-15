# API Gateway Service

The **API Gateway** serves as the unified entry point for all frontend requests in the GlobeTrotter ecosystem. It handles request routing, authorization token pass-through, CORS headers, and reverse proxying to underlying microservices.

## Port & Base Endpoint
- **Port**: `5000`
- **Base URL**: `http://localhost:5000`

## Proxy Mappings
- `/register`, `/login`, `/verify`, `/resend-code`, `/forgot-password`, `/reset-password`, `/auth/google`, `/preferences`, `/favorites` → **User Service** (`port 5001`)
- `/itineraries` (`GET`, `POST`, `PUT`, `DELETE`) → **Itinerary Service** (`port 5002`)
- `/destinations`, `/search`, `/recommendations` → **Recommendation Service** (`port 5003`)

## Running Locally

```bash
pip install -r requirements.txt
python run.py
```

## Healthcheck
`GET http://localhost:5000/health` returns status code `200` with status `healthy`.
