# GlobeTrotter — Smart Travel Assistant for Yaoundé, Cameroon

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Analytics-FFCA28?logo=firebase)](https://firebase.google.com/)
[![Python](https://img.shields.io/badge/Python-3.12%2B-3776AB?logo=python)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-3.0%2B-000000?logo=flask)](https://flask.palletsprojects.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Neon-4169E1?logo=postgresql)](https://neon.tech)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://www.docker.com/)

**GlobeTrotter Travel Assistant** is a modern, distributed microservices platform designed for exploring Cameroon's vibrant capital, Yaoundé. The application provides intelligent search, personalized recommendations, itinerary planning, rating/reviews, real-time background analytics, and multi-language support across Web, Mobile, and Desktop clients.

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
2. **User Service (`port 5001`)**: Handles user registration, email address syntax verification, 6-digit verification code email dispatch, bcrypt password hashing, JWT issuance, password reset, interest tag profiles, and favorites management.
3. **Itinerary Service (`port 5002`)**: Complete CRUD manager for multi-day itineraries, destinations sequencing, date range validation, and notes management.
4. **Recommendation Service (`port 5003`)**: Intelligent recommendation engine featuring preference matching, Foursquare venue search integration, ratings engine, community discussions, in-app notification center, public feedback/bug tracking, and destination parsing/synchronization from `destinations.txt`.
5. **Frontend Client (Flutter Web / Android / Desktop)**: Material 3 responsive UI featuring localized English/French interface, Firebase Analytics tracking, live in-app analytics dashboard, community feedback viewer, shimmer loading states, image lightboxes, tag chips, and real-time state synchronization.

---

## 2. Key Features

- 📊 **Firebase Analytics & Live Dashboard**: Integrated `firebase_core` and `firebase_analytics` streaming real-time events (`app_open`, `login`, `sign_up`, `search`, `view_destination`, `add_to_favorites`, `generate_itinerary`, `submit_feedback`). Includes a dedicated **Analytics Dashboard** available directly inside the app for all users.
- ✉️ **Strict Email Verification & Password Reset**: Robust RFC email address format validation on registration and password reset. Verification codes are dispatched directly to the user's valid email inbox for account activation and password recovery.
- 🔓 **Universal App Access**: All community features (Analytics Dashboard & Community Feedback) are open to all authenticated users without restrictive admin locks.
- 🔒 **Security & Authentication**: JWT token management, bcrypt salted password hashing, client-side secure storage fallback, and official Google Sign-In integration.
- 💬 **Community Feedback & Discussions**: Threaded comment section with nested reply threads, author comment editing, confirmation-guided deletions, reply notifications, and a dedicated Community Feedback & Bug Reports manager.
- 🔔 **In-App Notification Center**: Real-time notifications for comment replies, ratings, and travel updates with unread counts and batch mark-as-read.
- ⚡ **High-Performance Connection Pooling**: Microservices utilize `ThreadedConnectionPool` (1-15 connections) with explicit connection release and optimized B-tree indexes (`idx_users_email`, `idx_destinations_fsq_id`, `idx_itineraries_user_id`, `idx_comments_dest`, `idx_comments_parent`, `idx_notifications_user`).
- 🖼️ **Rich Media & Visual Gallery**: 20 synchronized Cameroonian destinations with high-resolution photo galleries, full-screen lightbox modal preview, and image deduplication.
- 💰 **Verified Details & Real Pricing**: Multi-paragraph verified descriptions, opening hours, direct phone dialing (`tel:`), official website links, and real prices in FCFA for every destination.
- 📅 **Itinerary CRUD & Auto-add**: Full create, read, update (PUT), and delete (DELETE) functionality for trip plans with direct "Add to Itinerary" action from destination details.
- 🌍 **Multilingual & Responsive**: Instant English/French toggle with persisted preferences, bottom navigation bar on mobile (`<850px`), permanent side navigation on desktop/web (`>=850px`).

---

## 3. Directory Structure

```
yaounde-globe-trotter/
├── frontend/                     # Flutter Web/Mobile/Desktop client codebase
│   ├── lib/
│   │   ├── config/               # API endpoint configurations & auto host resolver
│   │   ├── firebase_options.dart # Firebase CLI generated options (Android, Web, Windows)
│   │   ├── l10n/                 # AppLocalizations (English / French)
│   │   ├── models/               # Data models
│   │   ├── screens/              # MainShell, Destinations, Recommendations, AnalyticsDashboard, Auth
│   │   ├── services/             # AnalyticsService, ApiService, AuthProvider, FavoritesProvider
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

- **Windows Desktop**:
  ```bash
  cd frontend
  flutter run -d windows
  ```

---

## 6. Firebase Analytics Configuration

Firebase configuration file `lib/firebase_options.dart` is automatically created via FlutterFire CLI:
```bash
cd frontend
dart pub global run flutterfire_cli:flutterfire configure
```
Supported platform targets: **Android**, **Web**, **Windows**.

---

## 7. Testing & Verification

### Backend Microservice Test Suite
Run pytest from within each microservice directory:
```bash
cd services/user-service && python -m pytest
cd services/itinerary-service && python -m pytest
cd services/recommendation-service && python -m pytest
```

### Frontend Analysis & Verification
Verify Flutter static analysis:
```bash
cd frontend
flutter analyze
```

---

## 8. License

This project is released under the [MIT License](LICENSE).