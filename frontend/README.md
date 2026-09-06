# GlobeTrotter Frontend Client

The **GlobeTrotter Frontend** is a modern, responsive cross-platform client built with Flutter (Material 3), supporting Web, Mobile (Android/iOS), and Desktop (Windows/macOS/Linux).

## Key Features

- 💬 **Live Global Community Chat (`LiveChatScreen`)**:
  - Global real-time community chat room accessible to all app users (authenticated users & guests).
  - Automatic candidate host resolver connecting directly to backend microservices over IPv4 (`http://127.0.0.1:5003`).
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
2. Configure **ADB Reverse Port Forwarding**:
   ```bash
   adb reverse tcp:5000 tcp:5000
   adb reverse tcp:5003 tcp:5003
   ```
3. Run on your connected phone:
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

---

### Static Analysis & Testing
```bash
flutter analyze
flutter test
```

---

### Production Web Build
```bash
flutter build web --release --no-tree-shake-icons
```
The production bundle will be generated under `build/web/`.

