# GlobeTrotter – Travel Assistant

GlobeTrotter is a **monolithic Flask application** that serves as the starting point for a semester-long capstone project. Students build the monolith first, refactor it into microservices, and deploy it to the cloud using Docker, Kubernetes, and cloud-native tooling.

---

## Project Structure

```
.
├── app/
│   ├── __init__.py         # Flask app factory & CORS configuration
│   ├── models.py           # Data models and JSON file I/O
│   ├── auth.py             # Registration, login, JWT handling & @token_required decorator
│   ├── destinations.py     # Destination search endpoint
│   ├── recommendations.py  # Personalised recommendations endpoint
│   ├── itineraries.py      # Create / list itineraries
│   └── main.py             # App entry point
├── data/
│   ├── destinations.json   # Static destination catalogue (seed data)
│   ├── users.json          # Created at runtime
│   └── itineraries.json    # Created at runtime
├── tests/
│   └── test_api.py         # Automated pytest test suite
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── README.md
```

---

## API Endpoints Specification

Protected endpoints require the HTTP Authorization header:  
`Authorization: Bearer <your_jwt_token>`

### Public Endpoints

* **POST `/register`**
  * **Description**: Create a new user account.
  * **Request Body**: `{"username": "alice", "password": "s3cr3t", "preferences": ["beach", "food"]}`
  * **Responses**: `201 Created` on success, `400 Bad Request` if missing fields, `409 Conflict` if username exists.

* **POST `/login`**
  * **Description**: Authenticate user credentials and receive a JWT.
  * **Request Body**: `{"username": "alice", "password": "s3cr3t"}`
  * **Responses**: `200 OK` with `{"token": "<jwt>"}` on success, `401 Unauthorized` on bad credentials.

* **GET `/destinations`**
  * **Description**: Search the travel catalogue.
  * **Query Parameters (Optional)**: `q` (free-text search), `tag` (interest tag), `continent` (continent name), `max_cost` (max daily cost integer).
  * **Responses**: `200 OK` with JSON array of matching destinations.

### Protected Endpoints (JWT Required)

* **GET `/recommendations`**
  * **Description**: Retrieve personalized destination recommendations scored against user preference tags.
  * **Query Parameters (Optional)**: `limit` (default: 5).
  * **Responses**: `200 OK` with scored destinations, `401 Unauthorized` if token missing/invalid.

* **POST `/itineraries`**
  * **Description**: Create a new travel itinerary for the logged-in user.
  * **Request Body**: `{"title": "Beach Escape", "destinations": ["Bali"], "start_date": "2025-07-01", "end_date": "2025-07-14", "notes": "Optional notes"}`
  * **Responses**: `201 Created` with itinerary object, `400 Bad Request` if required fields missing, `401 Unauthorized` if unauthenticated.

* **GET `/itineraries`**
  * **Description**: List all itineraries belonging to the authenticated user.
  * **Responses**: `200 OK` with JSON array of itineraries, `401 Unauthorized` if unauthenticated.

---

## Testing the API

### Windows (PowerShell)

```powershell
# 1. Register a new user (Note: returns 409 if user already registered)
Invoke-RestMethod -Uri http://localhost:5000/register -Method Post -ContentType "application/json" -Body '{"username": "alice", "password": "s3cr3t", "preferences": ["beach", "food"]}'

# 2. Login and store JWT token in variable
$token = (Invoke-RestMethod -Uri http://localhost:5000/login -Method Post -ContentType "application/json" -Body '{"username": "alice", "password": "s3cr3t"}').token

# 3. Search destination catalogue
Invoke-RestMethod -Uri "http://localhost:5000/destinations?tag=beach&max_cost=100"

# 4. Get personalised recommendations
Invoke-RestMethod -Uri http://localhost:5000/recommendations -Headers @{ Authorization = "Bearer $token" }

# 5. Create an itinerary
Invoke-RestMethod -Uri http://localhost:5000/itineraries -Method Post -ContentType "application/json" -Headers @{ Authorization = "Bearer $token" } -Body '{"title": "Beach Escape", "destinations": ["Bali"], "start_date": "2025-07-01", "end_date": "2025-07-14"}'

# 6. List user itineraries
Invoke-RestMethod -Uri http://localhost:5000/itineraries -Headers @{ Authorization = "Bearer $token" }
```

### Linux / macOS / Git Bash (cURL)

```bash
# 1. Register
curl -X POST http://localhost:5000/register \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "s3cr3t", "preferences": ["beach", "food"]}'

# 2. Login
curl -X POST http://localhost:5000/login \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "s3cr3t"}'

# 3. Search destinations
curl "http://localhost:5000/destinations?tag=beach&max_cost=100"

# 4. Personalised recommendations
curl http://localhost:5000/recommendations \
  -H "Authorization: Bearer <TOKEN>"

# 5. Create an itinerary
curl -X POST http://localhost:5000/itineraries \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{"title": "Beach Escape", "destinations": ["Bali"], "start_date": "2025-07-01", "end_date": "2025-07-14"}'

# 6. List itineraries
curl http://localhost:5000/itineraries \
  -H "Authorization: Bearer <TOKEN>"
```

---

## Local Development & Testing

### Prerequisites
- Python 3.9+
- pip

### Steps

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Start the server
python app/main.py

# 3. Run automated pytest suite
python -m pytest
```

The server listens locally at `http://localhost:5000`.

---

## Docker Setup

To build and run the application in a Docker container:

```bash
# Build image and start container
docker-compose up --build

# Stop container service
docker-compose down
```

The `data/` directory is mounted into the container as a volume so runtime JSON data persists between container restarts.

---

## Data Persistence Strategy

All application data is stored in plain JSON files within the `data/` folder:

* **`data/destinations.json`**: Static seed catalogue of travel destinations.
* **`data/users.json`**: Runtime user account records with password hashes and preference tags (excluded from git).
* **`data/itineraries.json`**: Runtime user itineraries (excluded from git).

---

## Environment Variables Configuration

* **`SECRET_KEY`**: JWT token signing secret.
  * Default: `globetrotter-secret-change-in-prod`
  * Important: Set to a strong random key in production environments.
* **`FLASK_DEBUG`**: Enables Flask development mode when set to `1`.
  * Default: `0`
* **`PORT`**: Server listener port.
  * Default: `5000`
