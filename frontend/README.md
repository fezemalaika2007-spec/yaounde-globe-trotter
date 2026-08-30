# GlobeTrotter Frontend Client

The **GlobeTrotter Frontend** is a modern, responsive cross-platform client built with Flutter (Material 3), supporting Web, Mobile (Android/iOS), and Desktop (Windows/macOS/Linux).

## Key Features

- 📊 **Firebase Analytics & Live Dashboard**:
  - Background event tracking via `firebase_core` and `firebase_analytics`.
  - Automatic and custom event tracking (`logAppOpen`, `logLogin`, `logSignUp`, `logSearch`, `logViewDestination`, `logToggleFavorite`, `logGenerateItinerary`, `logSubmitFeedback`).
  - **In-App Analytics Dashboard** (`AnalyticsDashboardScreen`): Visual KPI cards, destination popularity charts, search keyword trends, and live session event logs available directly in the app.
- ✉️ **Strict Email Verification & Inbox Delivery**:
  - RFC email address format validation on registration and password reset.
  - Dispatch of 6-digit verification codes to the user's valid email inbox for account verification and password recovery.
- 🔓 **Universal Feature Access**:
  - All community features (Analytics Dashboard, View Community Feedback) are open to all authenticated users without restrictive admin locks.
- 🎨 **Material 3 Travel Palette & Aesthetics**: Tailored warm terracotta & emerald palette (`#D9534F`, `#2E7D32`), customized card elevation, navigation bars, and rounded containers.
- 📱 **Adaptive & Responsive Layout**:
  - `<850px` (Mobile): Bottom `NavigationBar` and compact drawers.
  - `>=850px` (Desktop/Web): Permanent left sidebar navigation (`_SidebarPanel`) with responsive grid adaptation.
- ⚡ **Shimmer Loading State**: Skeletal loading animations (`ShimmerGrid`, `ShimmerLoading`) to prevent layout shift.
- 🖼️ **Full-Screen Gallery Lightbox**: Uncropped `BoxFit.contain` modal image viewer with swipe gestures, page indicators, and real venue captions.
- 💬 **Threaded Community Comments & Feedback**: Full commenting system with inline reply threads, comment editing, confirmation-guided deletions, reply notifications, and Community Feedback manager.
- 🌟 **Official Google Sign-In Branding**: Authentic 4-color Google vector logo (`GoogleLogoWidget`) adhering strictly to Google Brand Identity Guidelines.
- 🌐 **Comprehensive Place Information**: Opening hours, contact telephone numbers with direct calling (`tel:`), official website links, amenities tags, and real prices in FCFA.
- 🌍 **Multilingual Localization**: English and French in-app localization with persisted language preference.
- 📝 **Itinerary Management**: Interactive creation, edition (PUT), and deletion (DELETE) dialogs with date pickers.

## Building and Running

### Prerequisites
- Flutter SDK `^3.19.0` or higher
- Chrome browser (for Web execution) or Android Emulator / Physical Device / Windows Desktop

### Run Web Mode
```bash
flutter run -d chrome
```

### Run Android Mode
```bash
flutter run -d android
```

### Run Windows Desktop Mode
```bash
flutter run -d windows
```

### Configure Firebase
```bash
dart pub global run flutterfire_cli:flutterfire configure
```

### Static Analysis & Verification
```bash
flutter analyze
flutter test
```

### Production Web Build
```bash
flutter build web --release
```
The production bundle will be generated under `build/web/`.
