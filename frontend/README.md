# GlobeTrotter Frontend Client

The **GlobeTrotter Frontend** is a modern, responsive cross-platform client built with Flutter (Material 3), supporting Web, Mobile (Android/iOS), and Desktop (Windows/macOS/Linux).

## Key Features

- 💬 **Live Global Community Chat (`LiveChatScreen`)**:
  - Global real-time community chat room accessible to all app users (authenticated users & guests).
  - Uses the VPS API gateway at `http://185.202.223.228/api`, without local host fallbacks.
  - Quick action controls for message authors: inline message editing (✏️), message deletion (🗑️), and quote replies with target message preview.
  - Rich media capabilities: photo upload preview, video URL rendering, interactive emoji picker, and sticker gallery.
- 👤 **Profile Display Name Management (`ProfileScreen`)**:
  - Displays user's saved display name directly beneath profile picture avatar with one-touch Edit (✏️) and Delete (🗑️) options.
  - Clean text entry field without misleading example hint text.
  - Instant display name synchronization across chat avatar badges, posted messages, and navigation shell headers (`AuthProvider`).
- ✉️ **Direct Email Feedback Delivery (`FeedbackScreen`)**:
  - Pre-fills and opens native mail client or web Gmail compose window (`mail.google.com/mail/?view=cm&to=fezemalaika2007@gmail.com`).
  - Formats feedback category, user description, star rating, device metadata, and contact email directly for developer `fezemalaika2007@gmail.com`.
- 📊 **Firebase Analytics & Live Dashboard (`AnalyticsDashboardScreen`)**:
  - Background event tracking via `firebase_core` and `firebase_analytics`.
  - Tracked actions: `logAppOpen`, `logLogin`, `logSignUp`, `logSearch`, `logViewDestination`, `logToggleFavorite`, `logGenerateItinerary`, `logSubmitFeedback`.
  - **In-App Analytics Dashboard**: Visual KPI cards, destination popularity breakdown, search term trends, and live session event log table.
- 🎨 **Material 3 Travel Palette & Aesthetics**: Warm terracotta & emerald palette (`#D9534F`, `#2E7D32`), customized card elevation, custom navigation bars, and rounded containers.
- 📱 **Adaptive & Responsive Layout**:
  - `<850px` (Mobile): Bottom `NavigationBar` and compact drawers.
  - `>=850px` (Desktop/Web): Permanent left sidebar navigation (`_SidebarPanel`) with responsive grid adaptation.
- ⚡ **Shimmer Loading State**: Skeletal loading animations (`ShimmerGrid`, `ShimmerLoading`) preventing layout shifts.
- 🖼️ **Full-Screen Gallery Lightbox**: Uncropped `BoxFit.contain` modal image viewer with swipe gestures, page indicators, and real Cameroonian venue captions.
- 🌟 **Official Google Sign-In Branding**: Authentic 4-color Google vector logo (`GoogleLogoWidget`) adhering strictly to Google Brand Guidelines.
- 🌍 **Multilingual Localization**: English and French in-app localization with persisted language preference.
- 📝 **Itinerary Management**: Interactive creation, edition (PUT), and deletion (DELETE) dialogs with date pickers.

---

## Building and Running

### Prerequisites
- Flutter SDK `^3.19.0` or higher
- Chrome browser (for Web execution) or Android Device (physical phone/emulator) / Windows Desktop

---

### Run Web Mode
```bash
flutter run -d chrome
```

---

### Run Android Physical USB Device

1. Enable **USB Debugging** on your Android phone and connect it via USB.
2. Run on your connected phone with an internet connection (no ADB port forwarding is needed):
   ```bash
   flutter run -d <your_device_id>
   ```

---

### Run Windows Desktop Mode
```bash
flutter run -d windows
```

---

### Configure Firebase Options
```bash
dart pub global run flutterfire_cli:flutterfire configure
```

Add `https://yaoundeglobe.duckdns.org` to the Google OAuth web client's
Authorized JavaScript origins before using Google sign-in in production.

---

### API Configuration

The frontend runs locally on your PC and defaults to
`http://185.202.223.228/api`. On the VPS, the IP-specific Nginx server in
`../deploy/nginx/yaoundeglobe.conf` must forward port 80 `/api/` requests to
the API gateway on `127.0.0.1:5000`. Port 5000 stays private. This API
endpoint does not require DuckDNS or a domain certificate.

Chat uses this same gateway for listing, sending, editing, and deleting
messages, including when a request fails; it never retries against the
visitor's local machine.

### Shared community chat

- Everyone can read the community feed. Sign-in is required to send text,
  emojis, stickers, photos, or videos; only the sender can edit or delete a message.
- The latest 100 messages refresh every three seconds. Failed refreshes keep
  the last loaded messages visible and show an error instead of an empty room.
- Attach one JPEG, PNG, GIF, WebP, MP4, or WebM file per message, up to 20 MB.
  Videos have play/pause and seek controls and load only when tapped.
  Playback depends on the browser/device supporting the video's codec.
- Files upload through `/api/chat/uploads` and are shared through
  `/api/chat/media/...`; messages contain a URL instead of embedding the whole
  file in every refresh. Failed sends retain the draft and uploaded attachment
  for retry.
- This is a public community space, not private messaging. Other visitors can
  read the messages and open the attachments.

Backend storage and the first-upgrade database preservation steps are documented
in the root [deployment guide](../README.md#upgrading-shared-chat-without-losing-existing-data).

### Mobile navigation

On screens narrower than 850 pixels, use the top-left menu to switch between
Home, Destinations, Recommendations, Favorites, and Itineraries. There is no
bottom navigation bar. Wider screens keep the permanent sidebar. The chat's
message composer remains available at the bottom of the conversation.

HTTP does not encrypt passwords, tokens, or other traffic. For real
credentials or a frontend hosted over HTTPS, use the HTTPS domain override
below once the domain and certificate are configured; browsers block HTTP
API calls from HTTPS pages.

For intentional local development only, override the backend at build/run time:
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5000
```
Do not include this local override when building for the VPS. Rebuild the
Flutter web bundle after configuration changes; restarting Nginx alone does
not update the compiled API URL.

---

### Static Analysis & Testing
```bash
flutter analyze
flutter test
```

---

### Production Web Build
```bash
flutter build web --release --no-tree-shake-icons --dart-define=API_BASE_URL=https://yaoundeglobe.duckdns.org/api
```
This HTTPS-hosted build explicitly uses the HTTPS API. For the local-PC
frontend with the IP-based API, omit the `--dart-define` argument.
The production bundle will be generated under `build/web/`.

### Frontend updates and browser caches

Nginx requires browsers to revalidate Flutter startup scripts (including
`main.dart.js`), `version.json`, and `manifest.json` before reusing cached copies.
Other static assets retain their seven-day cache policy.

Browsers that already cached an older build under the previous policy may still
use its old API address. After deploying this configuration, hard-refresh the
page. If needed, clear site data for this domain and reload; this signs you out.
A private window can confirm whether an error is specific to cached browser data.

---

## 🐳 Docker Containerization

The frontend application can be built and run as an isolated containerized service using Docker and Nginx.

### Option A: Using Docker Compose (Recommended)

Run directly from within the `frontend/` directory:
```bash
cd frontend
docker compose up -d --build
```
Access the application locally at `http://localhost:8080`. On the production
VPS, host Nginx proxies `https://yaoundeglobe.duckdns.org` to this loopback
port.

To stop the container:
```bash
docker compose down
```

---

### Option B: Using Docker CLI

1. **Build the Docker image**:
   ```bash
   cd frontend
   docker build -t globetrotter-frontend:latest .
   ```

2. **Run the container**:
   ```bash
   docker run -d -p 8080:80 --name globetrotter-frontend globetrotter-frontend:latest
   ```
   Access the application at `http://localhost:8080`.

3. **Stop and remove the container**:
   ```bash
   docker stop globetrotter-frontend
   docker rm globetrotter-frontend
   ```

---

### Key Containerization Configuration Files
- **`Dockerfile`**: Nginx 1.25-alpine image that copies the existing `build/web/` bundle. Build Flutter first; rebuilding the container alone does not update the compiled API address.
- **`nginx.conf`**: Single Page Application (SPA) `try_files` route fallback, Gzip compression, and asset caching headers.
- **`docker-compose.yml`**: Loopback-only port mapping `127.0.0.1:8080:80`
  with built-in HTTP healthchecks.
- **`.dockerignore`**: Excludes native mobile/desktop platforms and build artifacts to minimize Docker build context.
