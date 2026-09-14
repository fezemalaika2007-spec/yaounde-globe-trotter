import 'package:flutter/foundation.dart' show kIsWeb;

/// Google Sign-In configuration.
///
/// To enable Google Sign-In you must create a Google OAuth client ID for your
/// project at the Google Cloud Console:
///
///   https://console.cloud.google.com/apis/credentials
///
/// Then paste the appropriate client ID into [webClientId] (for the web app)
/// and/or [androidClientId] (for Android). Each platform needs its own client
/// ID:
///
///   * **Web**   → create an "OAuth client ID" of type **Web application** and
///                 add your app's origin (e.g. http://localhost:60394) to the
///                 "Authorized JavaScript origins".
///   * **Android** → create an "OAuth client ID" of type **Android** using your
///                 app's package name + SHA-1 signing certificate, and place
///                 the generated `google-services.json` in
///                 `android/app/`.
///
/// If no client ID is configured, the "Continue with Google" button shows a
/// clear message instead of failing silently.
class GoogleAuthConfig {
  /// Your Google OAuth **web** client ID (e.g.
  /// `xxxxx.apps.googleusercontent.com`). Leave empty to disable web Google
  /// sign-in gracefully.
  static const String webClientId =
      '824888913806-usgcqsvb37aic8tgjs72fv33kbjtrhf5.apps.googleusercontent.com';

  /// Your Google OAuth **Android** client ID. Leave empty to disable Android
  /// Google sign-in gracefully.
  static const String androidClientId = '';

  /// Whether Google Sign-In is configured for the current platform.
  static bool get isConfigured {
    if (kIsWeb) return webClientId.isNotEmpty;
    return androidClientId.isNotEmpty || webClientId.isNotEmpty;
  }

  /// The client ID to use for the current platform (or empty if none).
  static String get clientId {
    if (kIsWeb) return webClientId;
    return androidClientId.isNotEmpty ? androidClientId : webClientId;
  }
}
