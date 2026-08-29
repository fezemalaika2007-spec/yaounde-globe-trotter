# API Gateway Service

The **API Gateway** serves as the unified reverse proxy and routing entry point for all client requests in the GlobeTrotter ecosystem. It handles request forwarding, authorization header pass-through, CORS headers, error encapsulation, and health checks across all microservices.

## Port & Base Endpoint
- **Port**: `5000`
- **Base URL**: `http://localhost:5000`

## Proxy Mappings

### 1. User & Authentication Service (`port 5001`)
- `POST /register`: New user registration
- `POST /login`: Credential authentication & JWT issuance
- `POST /verify`: 6-digit email confirmation code verification
- `POST /resend-code`: Resend email confirmation code
- `POST /forgot-password`: Request password reset code
- `POST /reset-password`: Set new password with verified code
- `POST /auth/google`: Google OAuth token exchange & account login
- `GET`, `POST /favorites`: User favorites management

### 2. Itinerary Service (`port 5002`)
- `GET`, `POST /itineraries`: List and create trip itineraries
- `PUT`, `DELETE /itineraries/<id>`: Update itinerary details and delete trip plans

### 3. Recommendation Service (`port 5003`)
- **Destinations & Ratings**:
  - `GET /destinations`: Filtered destinations catalog
  - `POST /destinations/<id>/rating`: Submit/update 1–5 star destination rating
  - `GET /destinations/<id>/user-rating`: Retrieve authenticated user's rating
  - `GET /recommendations`: Personalized recommendation sections
  - `GET /search`: Search places across Yaoundé
- **Community Comments & Threaded Discussions**:
  - `GET /destinations/<id>/comments`: Retrieve destination comments and replies
  - `POST /destinations/<id>/comments`: Post comment or reply with optional `parent_id`
  - `PUT /destinations/<id>/comments/<comment_id>`: Edit existing comment (author only)
  - `DELETE /destinations/<id>/comments/<comment_id>`: Delete comment and child replies (author only)
- **Notification System**:
  - `GET /notifications`: List all user notifications
  - `GET /notifications/unread-count`: Fetch count of unread notifications
  - `POST /notifications/<id>/read`: Mark a single notification as read
  - `POST /notifications/read-all`: Mark all notifications as read
- **Feedback & Bug Reporting**:
  - `GET`, `POST /feedback`: Submit user feedback or retrieve submissions (admin)
  - `POST /feedback/<id>/resolve`: Mark feedback ticket resolved (admin)
- **Media & Import**:
  - `POST /import-urls`: Import place URLs
  - `GET /api/image-proxy`: Image streaming proxy

## Running Locally & Testing

```bash
# Install dependencies
pip install -r requirements.txt

# Run gateway service
python run.py

# Run test suite
python -m pytest
```

## Healthcheck Endpoint
- **URL**: `GET http://localhost:5000/health`
- **Response**: Returns HTTP `200 OK` when all downstream services (`user-service`, `itinerary-service`, `recommendation-service`) are healthy, or `503 Service Unavailable` with a diagnostic breakdown if any microservice is degraded.

