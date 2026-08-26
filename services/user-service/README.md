# User Service

The **User Service** manages user authentication, security, user interest profiles, and bookmarked favorite places.

## Port & Base Endpoint
- **Port**: `5001`
- **Base URL**: `http://localhost:5001`

## Key Capabilities
- **Authentication**: Salted `bcrypt` password hashing, email format regex validation, minimum password length enforcement (>= 6 characters).
- **JWT Issuance**: Secure token generation with configurable `SECRET_KEY`.
- **Database Connection Pooling**: Built with `ThreadedConnectionPool` (1-15 connections) and `release_connection` safety guards.
- **SQL Indexes**: Includes B-tree indexes `idx_users_username`, `idx_users_email`, and `idx_favorites_user_id`.

## API Routes
- `POST /register`: Registers new user accounts with interest tags.
- `POST /login`: Authenticates credentials and returns a signed JWT.
- `GET /preferences`: Fetches user interest profile tags.
- `POST /preferences`: Updates user interest profile tags.
- `GET /favorites`: Returns all favorited destination names for the authenticated user.
- `POST /favorites`: Toggles favorite state for a destination.

## Running Locally & Testing

```bash
# Run service
pip install -r requirements.txt
python run.py

# Run test suite
python -m pytest
```
