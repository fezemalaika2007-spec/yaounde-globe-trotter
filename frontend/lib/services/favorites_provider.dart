import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Simple app-scoped favorites cache + notifier.
///
/// Keeps a local list of favorite destination names and notifies listeners
/// when it changes. All network operations are proxied through [ApiService].
class FavoritesProvider extends ChangeNotifier {
  static final FavoritesProvider _instance = FavoritesProvider._();
  factory FavoritesProvider() => _instance;
  FavoritesProvider._();

  final ApiService _api = ApiService();

  List<String> _favorites = [];
  List<String> get favorites => List.unmodifiable(_favorites);

  bool isFavorite(String name) => _favorites.contains(name);

  /// Load favorites from the backend. Swallows errors and leaves the list
  /// empty so the UI can show an empty state instead of an error page.
  Future<void> loadFavorites() async {
    try {
      final results = await _api.getFavorites();
      _favorites = results.cast<String>();
      notifyListeners();
    } catch (_) {
      // On any error, keep an empty list and notify so listeners can update.
      _favorites = [];
      notifyListeners();
    }
  }

  /// Toggle favorite state for [destinationName]. Returns the updated list.
  Future<List<String>> toggleFavorite(String destinationName) async {
    try {
      final updated = await _api.toggleFavorite(destinationName);
      _favorites = updated.cast<String>();
      notifyListeners();
      return _favorites;
    } catch (_) {
      rethrow;
    }
  }
}
