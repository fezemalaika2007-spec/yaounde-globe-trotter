# Itinerary Service — Yaoundé GlobeTrotter

The **Itinerary Service** is a core microservice of the Yaoundé GlobeTrotter backend platform. It handles full lifecycle management (creation, retrieval, updates, and deletion) of multi-day travel itineraries for authenticated users.

---

## 🚀 Port & Base Configuration

- **Default Port**: `5002`
- **Base URL**: `http://localhost:5002`
- **Network Protocol**: HTTP / RESTful JSON API
- **CORS**: Enabled via `flask-cors`

---

## 🛠️ Key Capabilities & Architecture

- **🔒 JWT Context Isolation**: All user-facing routes extract user identity strictly from the signed JWT Authorization header (`Bearer <token>`), guaranteeing data isolation per user.
- **⚡ High-Performance Connection Pooling**: Uses `psycopg2.pool.ThreadedConnectionPool` (1–15 connections) for efficient PostgreSQL access with explicit release handlers.
- **📊 B-Tree Indexing**: Database indexes (`idx_itineraries_username`, `idx_itineraries_user_id`) ensure fast lookups for user trip queries.
- **🔄 Inter-Service Communication**: Features internal endpoints (`/internal/users/<user_id>/itineraries`) allowing other microservices (such as Recommendation Service) to retrieve user trip context.
- **🛡️ Graceful DB Fallback & Test Safety**: Automatically handles environment variables and test contexts without breaking pipeline runs.

---

## 📡 API Reference

### Health Check

#### `GET /`
Returns the operational status of the Itinerary Service.
- **Response `200 OK`**:
  ```json
  {
    "status": "ok",
    "service": "itinerary-service"
  }
  ```

---

### Authenticated Endpoints (Requires `Authorization: Bearer <token>`)

#### `POST /itineraries`
Creates a new custom travel itinerary.
- **Headers**: `Authorization: Bearer <JWT>`
- **Request Body**:
  ```json
  {
    "title": "Weekend in Yaoundé",
    "destinations": ["Mont Fébé", "Mefou National Park", "National Museum"],
    "start_date": "2026-09-01",
    "end_date": "2026-09-05",
    "notes": "Remember to pack hiking gear."
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "id": "e6a4b12c-3d4f-4a12-8b9a-123456789abc",
    "username": "alice",
    "title": "Weekend in Yaoundé",
    "destinations": ["Mont Fébé", "Mefou National Park", "National Museum"],
    "start_date": "2026-09-01",
    "end_date": "2026-09-05",
    "notes": "Remember to pack hiking gear.",
    "created_at": "2026-08-29T18:00:00+00:00"
  }
  ```
- **Error Responses**:
  - `400 Bad Request`: Missing required fields (`title`, `destinations`, `start_date`, or `end_date`).
  - `401 Unauthorized`: Missing or invalid JWT.

#### `GET /itineraries`
Retrieves all itineraries created by the authenticated user in reverse chronological order.
- **Headers**: `Authorization: Bearer <JWT>`
- **Response `200 OK`**:
  ```json
  [
    {
      "id": "e6a4b12c-3d4f-4a12-8b9a-123456789abc",
      "username": "alice",
      "title": "Weekend in Yaoundé",
      "destinations": ["Mont Fébé", "Mefou National Park"],
      "start_date": "2026-09-01",
      "end_date": "2026-09-05",
      "notes": "Remember to pack hiking gear.",
      "created_at": "2026-08-29T18:00:00+00:00"
    }
  ]
  ```

#### `PUT /itineraries/<itinerary_id>`
Updates an existing itinerary owned by the authenticated user.
- **Headers**: `Authorization: Bearer <JWT>`
- **Request Body**: (all fields optional)
  ```json
  {
    "title": "Updated Trip Title",
    "notes": "Added new stop"
  }
  ```
- **Response `200 OK`**: Returns updated itinerary JSON.
- **Error Response `404 Not Found`**: Itinerary does not exist or does not belong to the requesting user.

#### `DELETE /itineraries/<itinerary_id>`
Deletes an itinerary owned by the authenticated user.
- **Headers**: `Authorization: Bearer <JWT>`
- **Response `200 OK`**:
  ```json
  {
    "message": "itinerary deleted successfully"
  }
  ```
- **Error Response `404 Not Found`**: Itinerary does not exist or access denied.

---

### Internal Service Endpoints (Gateway / Inter-Service Only)

#### `GET /internal/users/<user_id>/itineraries`
Retrieves past itineraries for a given user UUID.
- **Response `200 OK`**: List of user itineraries.

---

## ⚙️ Environment Variables

| Variable | Description | Default / Example |
|---|---|---|
| `PORT` | HTTP port server listens on | `5002` |
| `DATABASE_URL` | Neon/PostgreSQL connection string | `postgresql://user:pass@host/db?sslmode=require` |
| `ITINERARY_DATABASE_URL` | Specific database connection override | *(Falls back to `DATABASE_URL`)* |
| `SECRET_KEY` | Shared secret key for JWT verification | `globetrotter-secret...` |
| `FLASK_DEBUG` | Enable debug mode (`1` for true) | `0` |

---

## 💻 Local Setup & Testing

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Run Service
```bash
python app/main.py
```

### 3. Run Test Suite
```bash
python -m pytest
```
