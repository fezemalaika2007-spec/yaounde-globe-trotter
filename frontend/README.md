# GlobeTrotter Frontend Client

The **GlobeTrotter Frontend** is a cross-platform client built with Flutter (Material 3), supporting Web, Mobile (Android/iOS), and Desktop (Windows/macOS/Linux).

## Key Features

- 🎨 **Material 3 Travel Palette & Aesthetics**: Tailored warm terracotta & emerald palette (`#D9534F`, `#2E7D32`), customized card elevation, navigation bars, and rounded containers.
- 📱 **Adaptive & Responsive Layout**:
  - `<850px` (Mobile): Bottom `NavigationBar` and compact drawers.
  - `>=850px` (Desktop/Web): Permanent left sidebar navigation (`_SidebarPanel`).
- ⚡ **Shimmer Loading State**: Skeletal loading states (`ShimmerGrid`, `ShimmerLoading`) to prevent blank layouts.
- 🖼️ **Full-Screen Gallery Lightbox**: Uncropped `BoxFit.contain` modal image viewer with page indicators and captions.
- 📍 **Interactive Location Cards**: Real latitude/longitude coordinates display with quick Google Maps navigation launcher.
- 🌍 **Multilingual Localization**: English and French in-app localization with persisted language preference.
- 📝 **Itinerary Management**: Interactive creation, edition (PUT), and deletion (DELETE) dialogs with date pickers.
- ⚡ **Web Safety**: Bypasses platform-specific filesystem blockers on Web and uses local storage fallback for JWT token storage.

## Building and Running

### Prerequisites
- Flutter SDK `^3.19.0`
- Chrome browser (for Web execution) or Android Emulator / Physical Device

### Run Web Mode
```bash
flutter run -d chrome
```

### Run Android Mode
```bash
flutter run -d android
```

### Static Analysis
```bash
flutter analyze
```

### Production Web Build
```bash
flutter build web --release
```
The production bundle will be generated under `build/web/`.
