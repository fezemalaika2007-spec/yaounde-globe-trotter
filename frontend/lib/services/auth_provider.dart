import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Application-level authentication state.
///
/// Exposes the user's login status so the UI can react accordingly
/// (e.g. show login vs. home screen).
///
/// This is a singleton — use [AuthProvider.instance] everywhere.
class AuthProvider extends ChangeNotifier {
  // Singleton
  static final AuthProvider _instance = AuthProvider._();
  factory AuthProvider() => _instance;
  AuthProvider._();

  final ApiService _api = ApiService();

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String? _username;
  String? get username => _username;

  /// Check whether a stored token exists (e.g. when the app starts).
  Future<void> checkAuthStatus() async {
    final token = await _api.getToken();
    _isLoggedIn = token != null;
    notifyListeners();
  }

  /// Attempt logging in.  Throws [ApiException] on failure.
  Future<void> login(String username, String password) async {
    await _api.login(username: username, password: password);
    _username = username;
    _isLoggedIn = true;
    notifyListeners();
  }

  /// Register a new user and immediately log them in.
  Future<void> register(
    String username,
    String password,
    List<String> preferences,
  ) async {
    await _api.register(
      username: username,
      password: password,
      preferences: preferences,
    );
    await _api.login(username: username, password: password);
    _username = username;
    _isLoggedIn = true;
    notifyListeners();
  }

  /// Log out: clear the stored token.
  Future<void> logout() async {
    await _api.deleteToken();
    _username = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
