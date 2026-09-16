/// API configuration for the GlobeTrotter backend.
///
/// All platforms connect to the VPS through its public HTTPS gateway.
class ApiConfig {
  static const String _productionBaseUrl =
      'https://yaoundeglobe.duckdns.org/api';

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// The base URL of the GlobeTrotter REST API (API Gateway).
  ///
  /// Set `API_BASE_URL` with `--dart-define` to explicitly use another backend.
  static String get baseUrl {
    if (_configuredBaseUrl.isEmpty) return _productionBaseUrl;
    return _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
  }

  // ---- Endpoints ----------------------------------------------------------

  static const String register = '/register';
  static const String login = '/login';
  static const String verify = '/verify';
  static const String resendCode = '/resend-code';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String googleAuth = '/auth/google';
  static const String destinations = '/destinations';
  static const String recommendations = '/recommendations';
  static const String itineraries = '/itineraries';
  static const String favorites = '/favorites';

  /// Live internet search for destinations in Yaoundé (Foursquare-backed).
  static const String search = '/search';

  static const String notifications = '/notifications';
  static const String feedback = '/feedback';
  static const String chat = '/chat/messages';
  static const String chatUploads = '/chat/uploads';
}
