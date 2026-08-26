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

  /// Load favorites from the backend.
  ///
  /// If [propagateErrors] is true, any exception is rethrown so callers can
  /// handle it explicitly. Otherwise errors are swallowed and the list is
  /// reset to empty so UI components can display a neutral empty state.
  Future<void> loadFavorites({bool propagateErrors = false}) async {
    try {
      final results = await _api.getFavorites();
      _favorites = results.cast<String>();
      notifyListeners();
    } catch (e) {
      if (propagateErrors) rethrow;
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
