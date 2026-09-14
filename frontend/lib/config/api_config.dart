import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// API configuration for the GlobeTrotter backend.
///
/// The base URL is chosen automatically based on the runtime platform so the
/// app can reach the API Gateway on your development machine no matter which
/// device you run it on:
///
///   * **Android emulator**        → http://10.0.2.2:5000  (emulator alias for
///                                   the host machine's localhost)
///   * **Physical Android device** → override [baseUrl] below to your PC's
///                                   LAN IP, e.g. http://192.168.1.50:5000
///   * **Web / Windows / other**   → http://localhost:5000
///
/// The API Gateway (and all microservices) run on those ports via Docker.
class ApiConfig {
  /// The default API Gateway port.
  static const int gatewayPort = 5000;

  /// The host seen from *inside an Android emulator* — special alias that
  /// maps to the host machine's loopback interface.
  static const String _androidEmulatorHost = '10.0.2.2';

  /// The host for web/windows/desktop — same machine as the backend.
  static const String _localHost = 'localhost';

  /// Automatically picks the correct API Gateway host for the current
  /// platform, so the app "just works" when run in an Android emulator.
  static String get _resolvedHost {
    // Web / desktop: the backend runs on the same machine.
    if (kIsWeb) return _localHost;

    // Android: the emulator route is localhost -> 10.0.2.2; physical
    // devices need a reachable LAN IP (override [manualBaseUrl]).
    if (defaultTargetPlatform == TargetPlatform.android) return _androidEmulatorHost;

    return _localHost;
  }


  /// If you run on a physical Android device (or a device that can't reach
  /// the default host), set this to your computer's LAN IP, e.g.
  /// `'http://192.168.1.50:5000'`, then change [useManualBaseUrl] to true.
  static const String manualBaseUrl = '';

  /// Set to true to force using [manualBaseUrl] instead of the auto-detected
  /// host (needed for physical devices / remote servers).
  static const bool useManualBaseUrl = false;

  /// The base URL of the GlobeTrotter REST API (API Gateway).
  ///
  /// For local development this points to the Flask server running on
  /// port 5000. Override with [manualBaseUrl] for physical devices.
  static String get baseUrl {
    if (useManualBaseUrl && manualBaseUrl.isNotEmpty) return manualBaseUrl;
    return 'http://$_resolvedHost:$gatewayPort';
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
}

