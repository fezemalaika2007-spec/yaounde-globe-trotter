# Yaounde.Trip - Fix Plan

## Information Gathered
- **Backend**: 4 Flask microservices (api-gateway, user-service, itinerary-service, recommendation-service) with SQLite databases  
  - Backend already has: recommendations engine, live search (`/search`), internal preferences endpoint, favorites endpoints
- **Frontend**: Flutter app with lazy tab loading, destination grid, favorites, recommendations  
  - Frontend already has: `searchDestinations()` in ApiService, `ApiConfig.search` endpoint

## Remaining Issues to Fix

### Phase 1: Frontend Search Bar - Live Internet Search
- [ ] Update `_DestinationsTab` in `main_shell.dart` to call live search API when local results are insufficient
- [ ] Show "Searching the web..." indicator during live search

### Phase 2: Fix Favorites Screen Error Handling
- [ ] Ensure `FavoritesScreen` properly handles errors and shows retry button
- [ ] Ensure `FavoritesProvider` load errors are propagated correctly

### Phase 3: Fix Destination Details Image Deduplication
- [ ] Ensure `DestinationDetailScreen` gallery deduplicates images properly

### Phase 4: Testing
- [ ] Generate unit tests for backend normalization and frontend widgets
