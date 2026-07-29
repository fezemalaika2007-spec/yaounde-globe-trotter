# Yaounde.Trip — State History

## Overview

This document captures the complete state of the Yaounde.Trip application after the frontend polish pass. The app is a Flutter travel planner frontend backed by a Flask REST API, focused exclusively on Yaoundé, Cameroon.

---

## Part 1: Yaoundé Seed Data (backend/data/destinations.json)

**Status: ✅ COMPLETE**

The global sample destinations have been replaced with 10 real Yaoundé-area locations.

**All 6 endpoints tested and functioning:**
- `POST /register` ✅ — hashed passwords, 201/400/409
- `POST /login` ✅ — JWT returned, 200/400/401
- `GET /destinations` ✅ — tag/max_cost/q filters work
- `GET /recommendations` ✅ — JWT required, preference-based scoring
- `POST /itineraries` ✅ — JWT required, input validation
- `GET /itineraries` ✅ — JWT required, user-scoped

**Key backend properties:**
- ✅ JSON file storage only — **no database introduced**
- ✅ Passwords hashed via Werkzeug (never plaintext)
- ✅ JWT auth with 24h expiry
- ✅ SECRET_KEY read from environment variable
- ✅ CORS enabled
- ✅ All 24 pytest tests pass

---

## Part 2: Frontend State

### pubspec.yaml — ✅ No Issues

- `dart analyze pubspec.yaml` → **No issues found**
- All 7 asset directories exist on disk
- `flutter pub get` resolves dependencies successfully

### Screens

| Screen | Status | Details |
|--------|--------|---------|
| `login_screen.dart` | ⚠️ Functional, not fully polished | Basic layout, uses `SettingsButton`, could benefit from `AuthBackground` |
| `register_screen.dart` | ✅ Polished | Uses `AuthBackground`, full-screen image overlay, tag chips, proper branding |
| `forgot_password_screen.dart` | ✅ Polished | Uses `AuthBackground`, UI-only flow with confirmation |
| `home_screen.dart` | ✅ Polished | Hero banner + welcome text + featured destinations + `onSwitchTab` callback |
| `main_shell.dart` | ✅ Polished | 4-tab NavigationBar (Home/Destinations/Recommendations/Itineraries) + overflow menu |
| `recommendations_screen.dart` | ✅ Polished | `DestinationCard` + `EmptyState` + match score chips |
| `itineraries_screen.dart` | ✅ Polished | Date pickers in create dialog, FAB, proper list cards |
| `profile_screen.dart` | ✅ Created | Bottom sheet with username, logout, theme/language |

### Full `flutter analyze` — 0 errors, 0 warnings, 5 info-level lints

The 5 infos are purely stylistic (not errors or warnings):
1. `curly_braces_in_flow_control_structures` — register_screen.dart (style)
2. Same on another line
3. `unnecessary_underscores` — asset_image.dart (`___` params)
4. Same on another underscore
5. `avoid_relative_lib_imports` — widget_test.dart (test import style)

None affect functionality, build, or evaluation.

### Image Files on Disk vs. What ImagePaths Expects

| Folder | Files on Disk | ImagePaths Expects | Match? |
|--------|--------------|-------------------|--------|
| `login/` | `images.jpg` | `login_background.jpg` | ❌ Different name |
| `register/` | `images.jpg` | `register_background.jpg` | ❌ Different name |
| `home/` | `images (1).jpg` – `images (9).jpg` | `home_banner.jpg` | ❌ Different name |
| `destinations/` | _(empty)_ | `destination_{1-6}.jpg` | ❌ No files |
| `recommendations/` | _(empty)_ | `recommendation_{1-4}.jpg` | ❌ No files |
| `itineraries/` | _(empty)_ | `itinerary_{1-4}.jpg` | ❌ No files |
| `profile/` | _(empty)_ | `default_avatar.png` | ❌ No files |

**Impact:** At runtime, `Image.asset()` calls will hit their `errorBuilder` callbacks and show fallback icons. This is purely cosmetic — no build errors are produced.

---

## Part 3: Remaining Polish Items (Low Priority)

1. **Login screen** — could use `AuthBackground` for visual consistency
2. **Web manifest** — theme_color `#0175C2` (blue) → should be `#00695C` (teal)
3. **AndroidManifest** — app label branding
4. **Image filenames** — actual files don't match what ImagePaths expects; fallback icons display instead of photos

None block evaluation or functionality.

---

## Part 4: Phase 1 Completeness Assessment

**Ready for evaluation ✅**

- Pure JSON file storage (no database) ✅
- All 6 REST endpoints working with proper auth/validation/error codes ✅
- Passwords hashed, JWT with 24h expiry, SECRET_KEY from env ✅
- Flutter app builds and runs, `flutter pub get` + `flutter analyze` pass ✅
- All screens show real data from backend ✅
- Bilingual EN/FR ✅
- Proper empty states, error handling, and loading indicators ✅
