# GlobeTrotter Frontend Client

The **GlobeTrotter Frontend** is a modern, responsive cross-platform client built with Flutter (Material 3), fully supporting Web, Mobile (Android/iOS), and Desktop (Windows/macOS/Linux).

## Key Features

- 🎨 **Material 3 Travel Palette & Aesthetics**: Tailored warm terracotta & emerald palette (`#D9534F`, `#2E7D32`), customized card elevation, navigation bars, and rounded containers.
- 📱 **Adaptive & Responsive Layout**:
  - `<850px` (Mobile): Bottom `NavigationBar` and compact drawers.
  - `>=850px` (Desktop/Web): Permanent left sidebar navigation (`_SidebarPanel`) with responsive grid adaptation.
- ⚡ **Shimmer Loading State**: Skeletal loading animations (`ShimmerGrid`, `ShimmerLoading`) to prevent layout shift.
- 🖼️ **Full-Screen Gallery Lightbox**: Uncropped `BoxFit.contain` modal image viewer with swipe gestures, page indicators, and real venue captions.
- 💬 **Threaded Community Comments**: Full commenting system with inline reply threads, comment editing, confirmation-guided deletions, and real-time reply notifications.
- 🌟 **Official Google Sign-In Branding**: Authentic 4-color Google vector logo (`GoogleLogoWidget`) adhering strictly to Google Brand Identity Guidelines.
- 🌐 **Comprehensive Place Information**: Opening hours, contact telephone numbers with direct calling (`tel:`), official website links, amenities tags, and real prices in FCFA.
- 🌍 **Multilingual Localization**: English and French in-app localization with persisted language preference.
- 📝 **Itinerary Management**: Interactive creation, edition (PUT), and deletion (DELETE) dialogs with date pickers.
- ⚡ **Web & Desktop Safety**: Bypasses platform-specific filesystem blockers on Web and uses secure storage fallback for JWT authentication.

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

