<<<<<<< HEAD
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
1. **API Gateway (`port 5000`)**: Single entry point handling reverse proxying, CORS header negotiation, dynamic route forwarding, and consolidated health diagnostics.
2. **User Service (`port 5001`)**: Handles user registration, email verification with 6-digit confirmation codes, password reset with code validation, Google OAuth sign-in, JWT token generation, interest profile tags, and favorites.
3. **Itinerary Service (`port 5002`)**: Complete CRUD manager for multi-day itineraries, destinations sequencing, date range validation, and trip notes.
4. **Recommendation Service (`port 5003`)**: Intelligent recommendation engine featuring preference matching, Foursquare integration, 1–5 star ratings, threaded community discussions, cascading comment deletion, notifications center, feedback ticketing, and destinations sync from `destinations.txt`.
5. **Frontend Client (Flutter Web / Android / Desktop)**: Material 3 responsive UI featuring localized English/French interface, skeleton loading state, image lightboxes, tag chips, official Google sign-in branding, and real-time state synchronization.

---

## 2. Key Features

- 🔒 **Security & Authentication**: Strict JWT context enforcement, salted password hashing, regex email validation, 6-digit email confirmation codes, password recovery, and official Google OAuth integration.
- 💬 **Threaded Community Discussions**: Destination comment sections with nested reply threads, author comment editing (`PUT`), cascading deletion (`DELETE`), and real-time reply notifications.
- 🔔 **In-App Notification Center**: Instant notifications for comment replies, ratings, and travel updates with unread counts and batch mark-as-read actions.
- ⚡ **High-Performance Connection Pooling**: Microservices utilize `ThreadedConnectionPool` (1-15 connections) with explicit connection release and optimized B-tree indexes (`idx_users_email`, `idx_destinations_fsq_id`, `idx_itineraries_user_id`, `idx_comments_dest`, `idx_comments_parent`, `idx_notifications_user`).
- 🖼️ **Rich Media & Visual Gallery**: 20 synchronized Cameroonian destinations with high-resolution photo galleries, full-screen lightbox modal preview, and image deduplication.
- 💰 **Verified Details & Real Pricing**: Detailed multi-paragraph descriptions, opening hours, direct phone dialing (`tel:`), official website links, and real prices in FCFA for every destination.
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
cd services/api-gateway && python -m pytest
cd services/user-service && python -m pytest
cd services/itinerary-service && python -m pytest
cd services/recommendation-service && python -m pytest
```

### Frontend Analysis & Verification
Verify Flutter compilation, static analysis, and execute the test suite:
```bash
cd frontend
flutter analyze
flutter test
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
=======
# GlobeTrotter — Smart Travel Assistant for Yaoundé, Cameroon

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Analytics-FFCA28?logo=firebase)](https://firebase.google.com/)
[![Python](https://img.shields.io/badge/Python-3.12%2B-3776AB?logo=python)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-3.0%2B-000000?logo=flask)](https://flask.palletsprojects.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Neon-4169E1?logo=postgresql)](https://neon.tech)
[![SQLite](https://img.shields.io/badge/SQLite-3-003B57?logo=sqlite)](https://www.sqlite.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://www.docker.com/)

**GlobeTrotter Travel Assistant** is a modern, microservices-powered platform designed for exploring Cameroon's vibrant capital, Yaoundé. The application provides intelligent search, personalized destination recommendations, itinerary planning, rating/reviews, live community chat with media sharing, direct email feedback delivery, real-time background analytics, and multi-language support across Web, Mobile (Android), and Desktop clients.

---

## 1. System Architecture

```
                                  +-----------------------+
                                  | Flutter Web / Mobile  |
                                  |   (Material 3 UI)     |
                                  +-----------+-----------+
                                              |
                                              | HTTP / REST (JWT / Guest)
                                              v
                                  +-----------------------+
                                  |  Recommendation Svc   |
                                  |      Port: 5003       |
                                  +---+-------+-------+---+
                                      |       |       |
                 +--------------------+       |       +--------------------+
                 |                            |                            |
                 v                            v                            v
    +-------------------------+  +-------------------------+  +-------------------------+
    |   Destinations Engine   |  |   Live Community Chat   |  | Direct Email Feedback   |
    | (Ratings & Sync DB)     |  | (Edit/Delete/Replies)   |  | (fezemalaika2007@...)   |
    +------------+------------+  +------------+------------+  +------------+------------+
                 |                            |                            |
                 v                            v                            v
    +---------------------------------------------------------------------------------------+
    |                             SQLite / Cloud PostgreSQL Database                        |
    |      (Destinations, Ratings, Community Comments, Live Chat Messages, User Profiles)   |
    +---------------------------------------------------------------------------------------+
```

### Microservice Components
1. **Recommendation & Chat Service (`port 5003`)**: Flask microservice serving recommendation scoring, venue search, ratings, live global community chat API, direct email feedback dispatcher, and local SQLite destination sync (`destinations.db`).
2. **API Gateway (`port 5000`)**: Single entry point handling routing, proxying, header forwarding, CORS, and endpoint distribution.
3. **User Service (`port 5001`)**: Handles user registration, RFC email format verification, verification code email dispatch, bcrypt password hashing, JWT issuance, password reset, interest tag profiles, and favorites management.
4. **Itinerary Service (`port 5002`)**: Complete CRUD manager for multi-day itineraries, destinations sequencing, date range validation, and notes management.
5. **Frontend Client (Flutter Web / Android USB / Desktop)**: Material 3 responsive UI featuring localized English/French interface, Firebase Analytics tracking, live in-app analytics dashboard, real-time community chat room, profile customization, direct email feedback helper, shimmer loading states, image lightboxes, and tag chips.

---

## 2. Key Features

- 💬 **Live Global Community Chat**:
  - Real-time global chat room open to all users (authenticated & guests with custom display names).
  - Robust multi-host automated connection resolver with explicit IPv4 binding (`http://127.0.0.1:5003`).
  - Rich media attachments: photo uploading, video links, interactive emoji picker, and sticker gallery.
  - Message interaction capabilities: inline message editing (✏️), deletion (🗑️), and threaded quote replies.
- 👤 **Profile Display Name Management**:
  - Profile screen displaying saved display name directly beneath profile avatar with one-touch Edit (✏️) and Delete (🗑️) controls.
  - Clean profile input field without distracting example hint text.
  - Dynamic name synchronization across Live Chat avatar tags, messages, and navigation header.
- ✉️ **Direct Email Feedback & Support**:
  - Direct single-click launch of native mail client or web Gmail compose (`mail.google.com/mail/?view=cm&to=fezemalaika2007@gmail.com`).
  - Pre-filled feedback payload containing issue category, user message, star rating, platform device metadata, and developer contact email (`fezemalaika2007@gmail.com`).
  - Server-side fallback dispatcher powered by FormSubmit & SMTP worker background threads.
- 📊 **Firebase Analytics & Live Dashboard**:
  - Integrated `firebase_core` and `firebase_analytics` streaming real-time events (`app_open`, `login`, `sign_up`, `search`, `view_destination`, `add_to_favorites`, `generate_itinerary`, `submit_feedback`).
  - Dedicated **Analytics Dashboard** (`AnalyticsDashboardScreen`) available directly inside the app for all users.
- 📱 **Mobile USB Connectivity & ADB Port Forwarding**:
  - Out-of-the-box support for tethered physical Android phones via USB cable.
  - Automatic port mapping scripts using `adb reverse` ensuring seamless communication between mobile device and host machine backend services (`127.0.0.1:5003`).
- 🔓 **Universal App Access & Micro-Animations**:
  - Open community feature access with smooth shimmer loading states (`ShimmerGrid`), full-screen gallery lightbox previews, and Material 3 design tokens.
- 🖼️ **Rich Media & Cameroonian Visual Gallery**:
  - Synchronized Cameroonian destination database (`destinations.txt` / `destinations.db`) featuring verified descriptions, opening hours, direct phone dialing (`tel:`), official website links, and real prices in FCFA.
- 🌍 **Multilingual & Responsive Layout**:
  - Instant English/French toggle with persisted preferences.
  - Responsive layout adjusting dynamically from mobile bottom navigation (`<850px`) to permanent desktop left sidebar (`>=850px`).

---

## 3. Directory Structure

```
yaounde-globe-trotter/
├── frontend/                     # Flutter Web / Mobile (Android) / Desktop codebase
│   ├── android/                  # Android native wrapper & Gradle build scripts (compileSdk 34)
│   ├── lib/
│   │   ├── config/               # API endpoint configurations & candidate host auto-resolver
│   │   ├── firebase_options.dart # Firebase CLI generated options (Android, Web, Windows)
│   │   ├── l10n/                 # AppLocalizations (English / French)
│   │   ├── models/               # Data models (Destination, Comment, ChatMessage, User)
│   │   ├── providers/            # AuthProvider (profile display name state management)
│   │   ├── screens/              # MainShell, Destinations, LiveChatScreen, ProfileScreen, FeedbackScreen, AnalyticsDashboardScreen
│   │   ├── services/             # AnalyticsService, ApiService, FavoritesProvider
│   │   ├── theme/                # Material 3 Travel color scheme & typography
│   │   ├── utils/                # Media helpers, image normalization & filters
│   │   └── widgets/              # ShimmerGrid, DestinationGridCard, LightboxModal
│   ├── pubspec.yaml
│   └── README.md
├── services/                     # Python Flask Microservices
│   ├── .env.example              # Environment variables template
│   ├── docker-compose.yml        # Docker Compose configuration
│   ├── itinerary-service/        # Itinerary Management Service
│   └── recommendation-service/   # Recommendations, Live Chat & Feedback Service
│       ├── app/
│       │   ├── main.py           # Service entrypoint
│       │   ├── routes.py         # Rest API routes (Chat, Recommendations, Feedback, Ratings)
│       │   └── models.py         # SQLite schema & database models
│       ├── destinations.db       # Synchronized local SQLite database
│       ├── parse_and_sync_destinations.py # File sync utility
│       ├── requirements.txt
│       └── README.md
├── destinations.txt              # Primary destination dataset source
├── run_web.bat                   # Automated Windows launcher (starts backend 5003 + Chrome)
├── sync_destinations.bat         # Batch script to update destinations database
└── README.md                     # Project root documentation
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
3. Configure environment variables in `.env`:
   ```env
   FOURSQUARE_API_KEY=your_foursquare_api_key
   SECRET_KEY=your_random_256bit_secret_key
   DEVELOPER_EMAIL=fezemalaika2007@gmail.com
   ALLOWED_ORIGINS=*
   ```

---

## 5. How to Run Locally

### Automated Launch (Windows Web Client + Backend)

Double-click `run_web.bat` in the project root, or execute:
```cmd
.\run_web.bat
```
This launcher automatically initializes the backend Recommendation Service on `http://127.0.0.1:5003` in a background window and starts the Flutter Web application in Chrome.

---

### Option A: Running on a Physical Android Phone via USB

1. **Connect your Android phone** to your computer using a USB cable and enable **USB Debugging** in Developer Options.
2. **Setup ADB Port Forwarding**:
   Reverse host ports so the Android phone can reach the local machine's backend services:
   ```bash
   adb reverse tcp:5000 tcp:5000
   adb reverse tcp:5003 tcp:5003
   ```
3. **Verify Connected Device**:
   ```bash
   flutter devices
   ```
4. **Run Application on Phone**:
   ```bash
   cd frontend
   flutter run -d <your_device_id>
   ```

---

### Option B: Running Microservices via Docker Compose

To run microservices inside Docker containers:
```bash
cd services
docker-compose up --build
```
This exposes:
- API Gateway: `http://localhost:5000`
- Recommendation & Chat Service: `http://localhost:5003`

---

### Option C: Running Backend Service Directly with Python

```bash
cd services/recommendation-service
pip install -r requirements.txt
python app/main.py
```
The service will start listening on `http://127.0.0.1:5003`.

---

## 6. Testing & Verification

### Backend Microservice Tests
Run `pytest` inside the recommendation service directory:
```bash
cd services/recommendation-service
python -m pytest
```

### Frontend Code Analysis & Tests
Verify Flutter static analysis and run component tests:
```bash
cd frontend
flutter analyze
flutter test
```

---

## 7. License

This project is released under the [MIT License](LICENSE).
>>>>>>> frontend
