# User Service

The **User Service** manages user authentication, account verification, password recovery, Google OAuth sign-in, user interest preferences, and bookmarked favorite destinations.

## Port & Base Endpoint
- **Port**: `5001`
- **Base URL**: `http://localhost:5001`

## Key Capabilities
- **Authentication & Security**: Salted `werkzeug` password hashing, regex email validation, minimum password length enforcement (>= 6 characters), and 24-hour signed JWT issuance (`HS256`).
- **Email Verification**: 6-digit confirmation codes sent upon registration with code expiration and resend capabilities.
- **Password Reset**: Automated 6-digit reset code generation, email dispatch, and secure password updates.
- **Google OAuth Sign-In**: Token exchange and automated profile provisioning with Google ID tokens.
- **Database Connection Pooling**: Built with `ThreadedConnectionPool` (1–15 connections) and `release_connection` safety wrappers.
- **SQL Indexes**: Includes B-tree indexes `idx_users_username`, `idx_users_email`, and `idx_favorites_user_id`.

## API Routes

### Authentication & Account Recovery
- `POST /register`: Registers a new user with username, email, password, and interest tags; sends a 6-digit verification code.
- `POST /verify`: Verifies email address using the 6-digit confirmation code.
- `POST /resend-code`: Generates and emails a fresh 6-digit verification code.
- `POST /login`: Authenticates username/email and password, returning a signed JWT.
- `POST /forgot-password`: Requests a 6-digit password reset code sent via email.
- `POST /reset-password`: Verifies the reset code and updates the user's password.
- `POST /auth/google`: Verifies Google OAuth token and logs in/registers the user.

### Favorites & Preferences
- `GET /favorites`: Retrieves all bookmarked favorite destination names for the authenticated user (JWT required).
- `POST /favorites`: Toggles favorite state (add/remove) for a destination (JWT required).
- `GET /internal/users/preferences`: Retrieves interest tags for the authenticated user (JWT required).
- `GET /internal/users/<user_id>/preferences`: Internal endpoint to fetch user preferences by ID.

### Health Check
- `GET /`: Returns service health status and identifier.

## Running Locally & Testing

```bash
# Install dependencies
pip install -r requirements.txt

# Run service
python run.py

# Run test suite
python -m pytest
```

