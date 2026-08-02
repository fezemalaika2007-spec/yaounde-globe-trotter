# Task Implementation Checklist

## Backend — Recommendation Service
- [x] 1. Make placeholder image selection deterministic (MD5) + pool helper in `image_utils.py`
- [x] 2. Add `search_overpass()` live internet search + stricter image dedup in `overpass_sync.py`
- [x] 3. Add `GET /search` endpoint + wire real `/recommendations` in `routes.py`
- [x] 4. Fix `_fetch_user_preferences` in `recommendations.py` to call new internal endpoint

## Backend — User Service + Gateway
- [x] 5. Add JWT-protected `GET /internal/users/preferences` (preferences + favorites) in `user-service/routes.py`
- [x] 6. Add `/search` proxy route in `api-gateway/routes.py`

## Frontend — Live Search + Image Dedup + Performance
- [x] 7. Add `/search` to `api_config.dart`; add `searchDestinations()` + injectable http.Client in `api_service.dart`
- [x] 8. Create `lib/utils/destination_filters.dart` (shared pure validity/dedup helpers)
- [x] 9. Destinations tab: local-first search + "Search online…" live Overpass action in `main_shell.dart`
- [x] 10. Unique-gallery helper + cacheWidth + prefer long_description in `destination_details_screen.dart`
- [x] 11. cacheWidth/gaplessPlayback in `destination_grid_card.dart` and `destination_card.dart`
- [x] 12. Recommendations screen: personalized picks + Trending/Top-rated + rich empty state

## Tests
- [x] 13. Add `frontend/test/destination_filters_test.dart` (pure function unit tests)
- [x] 14. Extend `frontend/test/destination_details_screen_test.dart` (unique gallery + long_description precedence)
- [x] 15. Extend `test_normalization.py` (image URL dedup/description quality)
- [x] 16. Add `test_recommendations.py` (scoring + diversity)
- [x] 17. Extend `test_user_service.py` (preferences endpoint)

## Verification
- [x] 18. Run `flutter analyze` and `flutter test`
- [x] 19. Run `pytest` for recommendation & user services
- [x] 20. All tests pass — task complete!
