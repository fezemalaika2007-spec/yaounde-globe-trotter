# GlobeTrotter — Smart Travel Assistant for Yaoundé, Cameroon

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.12%2B-3776AB?logo=python)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-3.0%2B-000000?logo=flask)](https://flask.palletsprojects.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Neon-4169E1?logo=postgresql)](https://neon.tech)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://www.docker.com/)

**GlobeTrotter Travel Assistant** is a modern, distributed microservices platform designed for exploring Cameroon's vibrant capital, Yaoundé. The application provides intelligent search, personalized recommendations, itinerary planning, rating/reviews, and multi-language support across Web, Mobile, and Desktop clients.

---

## 1. System Architecture

```
                                  +-----------------------+
                                  | Flutter Web / Mobile  |
                                  |   (Material 3 UI)     |
                                  +-----------+-----------+
                                              |
                                              | HTTP / REST (JWT)
                                              v
                                  +-----------------------+
                                  |  API Gateway (Flask)  |
                                  |      Port: 5000       |
                                  +---+-------+-------+---+
                                      |       |       |
                 +--------------------+       |       +--------------------+
                 |                            |                            |
                 v                            v                            v
    +-------------------------+  +-------------------------+  +-------------------------+
    |      User Service       |  |    Itinerary Service    |  | Recommendation Service  |
    |       Port: 5001        |  |       Port: 5002        |  |       Port: 5003        |
    +------------+------------+  +------------+------------+  +------------+------------+
                 |                            |                            |
                 | SQL Pool                   | SQL Pool                   | SQL Pool & Foursquare API
                 v                            v                            v
    +---------------------------------------------------------------------------------------+
    |                          Cloud PostgreSQL Database (Neon)                             |
    |      (Users, Interest Tags, Favorites, Itineraries, Destinations, Ratings & Photos)   |
    +---------------------------------------------------------------------------------------+
```

### Microservice Components
1. **API Gateway (`port 5000`)**: Single entry point handling routing, proxying, header forwarding, CORS, and endpoint distribution.
2. **User Service (`port 5001`)**: Handles user registration, bcrypt password hashing, JWT issuance, email format validation, interest tag profiles, and favorites management.
3. **Itinerary Service (`port 5002`)**: Complete CRUD manager for multi-day itineraries, destinations sequencing, date range validation, and notes management.
4. **Recommendation Service (`port 5003`)**: Intelligent recommendation engine featuring preference matching, Foursquare venue search integration, ratings engine, auto-seeding with high-resolution Unsplash destination photos, and category grouping (Nature, Culture, Dining, Shopping, Adventure).
5. **Frontend Client (Flutter Web / Android / Desktop)**: Material 3 responsive UI featuring localized English/French interface, shimmer skeleton loading state, image lightboxes, tag chips, map integration, and real-time state synchronization.

---

## 2. Key Features

- 🔒 **Security & Authentication**: Strict JWT context enforcement, bcrypt salted password hashing, regex email validation, and client token storage.
- ⚡ **High-Performance Connection Pooling**: Microservices utilize `ThreadedConnectionPool` (1-15 connections) with explicit connection release and optimized B-tree indexes (`idx_users_email`, `idx_destinations_fsq_id`, `idx_itineraries_user_id`).
- 🖼️ **Rich Media & Visual Gallery**: Photo gallery with full-screen lightbox modal preview, image deduplication, high-resolution Yaoundé landmarks (Mont Fébé, Musée National, Marché Central, Mvog-Betsi Zoo, Cathédrale, Monument de la Réunification, Bois Sainte Anastasie).
- 📍 **Interactive Maps & Navigation**: Map preview card with exact latitude/longitude coordinates and direct Google Maps navigation launcher.
- 📅 **Itinerary CRUD & Auto-add**: Full create, read, update (PUT), and delete (DELETE) functionality for trip plans with direct "Add to Itinerary" action from destination details.
- 🌍 **Multilingual & Responsive**: Instant English/French toggle with persisted preferences, bottom navigation bar on mobile (`<850px`), permanent side navigation on desktop/web (`>=850px`).

---

## 3. Directory Structure

```
yaounde-globe-trotter/
├── frontend/                     # Flutter Web/Mobile/Desktop client codebase
│   ├── lib/
│   │   ├── config/               # API endpoint configurations & auto host resolver
│   │   ├── l10n/                 # AppLocalizations (English / French)
│   │   ├── models/               # Data models
│   │   ├── screens/              # MainShell, Destinations, Recommendations, Itineraries, Auth
│   │   ├── services/             # ApiService (JWT, HTTP guard, retry timeouts), FavoritesProvider
│   │   ├── theme/                # Material 3 Travel color scheme & components
│   │   ├── utils/                # Image normalization & filters
│   │   └── widgets/              # ShimmerGrid, DestinationGridCard, EmptyState
│   ├── pubspec.yaml
│   └── README.md
├── services/                     # Python Flask Microservices
│   ├── .env.example              # Environment variables template
│   ├── docker-compose.yml        # Docker Compose configuration with healthchecks
│   ├── api-gateway/              # Flask API Gateway proxy
│   ├── user-service/             # User Management & Auth Service
│   ├── itinerary-service/        # Itinerary Management Service
│   └── recommendation-service/   # Recommendations & Foursquare Sync Service
├── run_web.bat                   # Convenient Windows launcher script
└── README.md                     # Root documentation
```

---

## 4. Environment Configuration

1. Navigate into the `services/` directory:
   ```bash
   cd services
   ```
2. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
3. Configure your `.env` variables:
   ```env
   FOURSQUARE_API_KEY=your_foursquare_api_key
   DATABASE_URL=postgresql://USER:PASSWORD@HOST/DATABASE?sslmode=require
   SECRET_KEY=your_random_256bit_secret_key
   ALLOWED_ORIGINS=*
   ```

---

## 5. How to Run Locally

### Option A: Running with Docker Compose (Recommended)

To start all backend microservices and API Gateway simultaneously:
```bash
cd services
docker-compose up --build
```
This starts:
- API Gateway at `http://localhost:5000`
- User Service at `http://localhost:5001`
- Itinerary Service at `http://localhost:5002`
- Recommendation Service at `http://localhost:5003`

### Option B: Running Microservices Manually

Open separate terminal windows for each service inside `services/`:

1. **User Service**:
   ```bash
   cd services/user-service
   pip install -r requirements.txt
   python run.py
   ```

2. **Itinerary Service**:
   ```bash
   cd services/itinerary-service
   pip install -r requirements.txt
   python run.py
   ```

3. **Recommendation Service**:
   ```bash
   cd services/recommendation-service
   pip install -r requirements.txt
   python run.py
   ```

4. **API Gateway**:
   ```bash
   cd services/api-gateway
   pip install -r requirements.txt
   python run.py
   ```

### Running the Frontend Client

To launch the Flutter client in web or desktop mode:

- **Web Mode**:
  ```bash
  cd frontend
  flutter run -d chrome
  ```
  *Alternatively, double click `run_web.bat` in the project root.*

- **Android Emulator**:
  ```bash
  cd frontend
  flutter run -d android
  ```

---

## 6. Testing

### Backend Microservice Test Suite
Run pytest from within each microservice directory:
```bash
cd services/user-service && python -m pytest
cd services/itinerary-service && python -m pytest
cd services/recommendation-service && python -m pytest
```

### Frontend Analysis & Verification
Verify Flutter compilation and static analysis:
```bash
cd frontend
flutter analyze
```

---

## 7. Deployment Guide

1. **Database Provisioning**: Ensure a PostgreSQL instance (e.g. Neon, AWS RDS, or GCP Cloud SQL) is active and update `DATABASE_URL` in `.env`.
2. **Container Registry**: Build and push Docker images to your registry (Docker Hub, ECR, GCR):
   ```bash
   docker build -t your-org/api-gateway:latest services/api-gateway
   docker build -t your-org/user-service:latest services/user-service
   docker build -t your-org/itinerary-service:latest services/itinerary-service
   docker build -t your-org/recommendation-service:latest services/recommendation-service
   ```
3. **Container Orchestration**: Deploy the images using Kubernetes (`kubectl apply -f k8s/`) or Docker Compose on a Cloud VM.
4. **Frontend Hosting**: Build the web distribution bundle and deploy to Vercel, Netlify, or AWS S3 + CloudFront:
   ```bash
   cd frontend
   flutter build web --release
   ```

---

## 8. License

This project is released under the [MIT License](LICENSE).