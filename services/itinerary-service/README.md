# Itinerary Service

The **Itinerary Service** manages creation, updates, listing, and deletion of custom travel itineraries for registered users.

## Port & Base Endpoint
- **Port**: `5002`
- **Base URL**: `http://localhost:5002`

## Key Capabilities
- **JWT Authentication & Context**: Extracts `user_id` strictly from JWT authorization headers (`g.current_user['id']`), ensuring data isolation per user.
- **Database Connection Pooling**: Utilizes `ThreadedConnectionPool` (1-15 connections) with explicit connection release handlers.
- **SQL Indexes**: Optimized with `idx_itineraries_username` and `idx_itineraries_user_id`.
- **Full CRUD Support**: Supports `GET`, `POST`, `PUT`, and `DELETE` endpoints for itinerary entities.

## API Routes
- `GET /itineraries`: Retrieves all itineraries created by the authenticated user.
- `POST /itineraries`: Creates a new itinerary for the authenticated user.
- `PUT /itineraries/<id>`: Updates title, dates, destinations list, or notes for an existing itinerary owned by the user.
- `DELETE /itineraries/<id>`: Deletes an itinerary owned by the user.

## Running Locally & Testing

```bash
# Run service
pip install -r requirements.txt
python run.py

# Run test suite
python -m pytest
```
