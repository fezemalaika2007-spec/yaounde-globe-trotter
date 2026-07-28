/// API configuration for the GlobeTrotter backend.
///
/// Change [baseUrl] to point to the deployed backend when moving through
/// Docker, Kubernetes, or cloud hosting in later phases.
class ApiConfig {
  /// The base URL of the GlobeTrotter REST API.
  ///
  /// For local development this points to the Flask server running on port 5000.
  /// In production, update this to the actual deployment URL.
  static const String baseUrl = 'http://localhost:5000';

  // ---- Endpoints ----------------------------------------------------------

  static const String register = '/register';
  static const String login = '/login';
  static const String destinations = '/destinations';
  static const String recommendations = '/recommendations';
  static const String itineraries = '/itineraries';
}
