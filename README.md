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

### Backend-only startup

The backend Compose file is in `services/`, not the repository root. All
three service implementations and the API gateway must be present, including
each service's `Dockerfile`, `requirements.txt`, and application sources.
The previously missing User and Itinerary service files have been restored
from their backend branches.

After uploading the complete backend and configuring `services/.env`, run
these commands on the VPS:

```bash
cd ~/yaounde-globe-trotter/services
docker compose config --quiet
docker compose up -d --build
docker compose ps
curl -f http://127.0.0.1:5000/health
```

If startup fails, inspect `docker compose logs --tail=100 user-service
itinerary-service api-gateway`. A successful image build alone does not verify
database connectivity; configure the production database URLs and a shared
`SECRET_KEY` before starting the services.

### Optional frontend hosting and HTTPS

The production target is `185.202.223.228`, served at
`https://yaoundeglobe.duckdns.org`. The frontend and API bind only to VPS
loopback; host Nginx owns public ports 80 and 443.

All Flutter platforms default to `https://yaoundeglobe.duckdns.org/api`,
including local development and community chat. This protects credentials and
avoids browser mixed-content blocking and native cleartext-HTTP restrictions.
Host Nginx proxies `/api/` to the private gateway on port 5000. The explicit
HTTPS build override below remains supported. The loopback addresses in Compose,
health checks, and host Nginx are intentional server-internal connections, not
browser API URLs.
Rebuild the frontend bundle after changing API configuration, and add
`https://yaoundeglobe.duckdns.org` to the Google OAuth web client's
Authorized JavaScript origins.

1. Point the DuckDNS `A` record for `yaoundeglobe.duckdns.org` to
   `185.202.223.228`. Allow inbound TCP ports 80 and 443 in the VPS firewall.
2. Copy `.env.example` to `services/.env`, then set the database URLs and a
   strong `SECRET_KEY`.
3. Build the Flutter bundle and start both Compose projects:
   ```bash
   cd frontend
   flutter build web --release --no-tree-shake-icons --dart-define=API_BASE_URL=https://yaoundeglobe.duckdns.org/api
   docker compose up -d --build
   cd ../services
   docker compose up -d --build
   cd ..
   ```
4. Install the host Nginx site and request the Let's Encrypt certificate:
   ```bash
   chmod +x deploy/configure-vps.sh
   sudo ./deploy/configure-vps.sh admin@example.com
   ```

The script verifies DNS, installs Nginx and Certbot, enables the virtual host,
redirects HTTP to HTTPS, enables certificate renewal, and performs a dry-run
renewal. Replace `admin@example.com` with the certificate renewal email.

### Upgrading shared chat without losing existing data

Chat belongs to the Recommendation Service, not the Itinerary Service.
The recommendation database is SQLite, regardless of the legacy PostgreSQL
comments above. Its database and uploaded media must be kept in persistent
storage; a container's writable layer is lost when it is recreated.

After committing/pushing the changes and pulling them on the VPS, preserve the
old database **before the first upgrade** if it is still stored at
`/recommendation-service/destinations.db` inside the existing container:

```bash
cd /root/yaounde-globe-trotter/services
test ! -e data/recommendation/destinations.db &&
mkdir -p data/recommendation &&
docker compose stop recommendation-service &&
docker cp recommendation-service:/recommendation-service/destinations.db \
  data/recommendation/destinations.db
```

The first command refuses to overwrite an existing persistent database. Do not
remove that database or repeat this migration on later updates. If copying fails,
keep the old container and resolve the copy error before recreating it.

Then rebuild the changed backend services:

```bash
docker compose up -d --build recommendation-service api-gateway
docker compose ps
curl -f https://yaoundeglobe.duckdns.org/api/health
```

The Compose bind mount keeps the database and chat media under
`services/data/recommendation/`. Back up this directory together; do not commit it
to Git or delete it when updating the application.

Recompile the frontend (its Docker image only copies the existing build):

```bash
cd /root/yaounde-globe-trotter/frontend &&
docker run --rm -v "$PWD:/app" -w /app ghcr.io/cirruslabs/flutter:stable \
  bash -c 'flutter pub get && flutter build web --release --no-tree-shake-icons --dart-define=API_BASE_URL=https://yaoundeglobe.duckdns.org/api' &&
docker compose up -d --build
```

Keep `client_max_body_size 25m;` in the host Nginx HTTPS server or its `/api/`
location so a 20 MB multipart upload fits. The supplied deployment template
already uses this limit. The same `/api/` proxy handles uploads and video range
requests; no extra public backend ports or certificates are needed.

Verify with two different accounts or browsers: send text, an emoji, a sticker,
a photo, and a short MP4/WebM video from one account; the other should see them
within the next refresh and be able to play the video, but not edit/delete the
first account's messages. A signed-out browser can read, but cannot send.
After this first upgrade, hard-refresh any browser still using an older bundle.

Chat opens at the latest messages; scrolling upward retrieves earlier pages
without replacing the conversation or moving the reader to the newest message.
Reopening the app does not clear server-side history. Verify scrollback after
deployment as well as sending: the frontend and backend must both include the
history-cursor update. Never remove the persistent data directory during updates.

### Google sign-in compatibility update

Older cached frontend builds used the malformed `/apidocker/` API prefix.
The Nginx template now internally rewrites it to `/api/`, preserving POST
bodies, authorization headers, and query strings. This allows cached Google
sign-in clients to work without weakening the authentication endpoint.

For an existing Certbot-managed installation, add the same legacy location block
from `deploy/nginx/yaoundeglobe.conf` to the **active HTTPS server block**, then
validate and reload Nginx. Do not rerun the initial Certbot setup or replace the
existing TLS configuration. Rebuild the User Service to pick up stale PostgreSQL
connection recovery and its JSON retry response; account data and chat storage
must remain intact. Refresh older browser tabs to use the canonical `/api/` URL.

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
  - Uses the VPS gateway at `https://yaoundeglobe.duckdns.org/api`, with no local host fallbacks.
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
- 📱 **Mobile USB Connectivity & Online Backend**:
  - Out-of-the-box support for tethered physical Android phones via USB cable.
  - Connects directly to the configured VPS gateway using the phone's internet connection; no ADB port forwarding is needed.
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
This launcher starts a local Recommendation Service and serves the Flutter
web bundle locally. The frontend still connects to the online VPS API by
default; the local service is not used unless `API_BASE_URL` is explicitly
overridden when building the bundle.

---

### Option A: Running on a Physical Android Phone via USB

1. **Connect your Android phone** to your computer using a USB cable and enable **USB Debugging** in Developer Options.
2. **Verify Connected Device** (an internet connection is required to reach the VPS):
   ```bash
   flutter devices
   ```
3. **Run Application on Phone**:
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
