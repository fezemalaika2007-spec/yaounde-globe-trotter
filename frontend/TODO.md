# Yaounde.Trip Frontend Polish - Implementation Plan

## Phase 1: Foundation Updates
- [x] Update pubspec.yaml assets to include all image subdirectories
- [ ] Update main.dart to use AppTheme
- [ ] Update app_localizations.dart (rename GlobeTrotter → Yaounde.Trip, add new strings)
- [ ] Update ImagePaths to match desired structure

## Phase 2: Auth Screens
- [ ] Rewrite Login Screen to use AuthBackground + full-screen background
- [ ] Add Forgot Password link on Login screen
- [ ] Create Forgot Password Screen (UI-only)
- [ ] Rewrite Register Screen to use AuthBackground

## Phase 3: Main App Screens
- [ ] Rewrite Home Screen (hero banner, welcome, featured, quick nav)
- [ ] Rename old HomeScreen → DestinationsScreen, use DestinationCard
- [ ] Rewrite Recommendations Screen using DestinationCard + empty state
- [ ] Rewrite Itineraries Screen with date pickers + destination dropdown

## Phase 4: Navigation & Shell
- [ ] Update MainShell with 4 tabs (Home, Destinations, Recommendations, Itineraries)
- [ ] Update MainShell titles to show "Yaounde.Trip"
- [ ] Add navigation routes in main.dart
- [ ] Add Profile Screen + access from settings menu

