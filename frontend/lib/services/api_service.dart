import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/api_config.dart';

/// Centralized service for all HTTP calls to the GlobeTrotter backend.
///
/// All network logic lives here – never scatter raw HTTP calls across UI
/// widgets.  The JWT is stored securely via [flutter_secure_storage] and
/// automatically attached to protected endpoints.
class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _tokenKey = 'jwt_token';
  static const String _prefsTokenKey = 'jwt_token_prefs';

  // ---------------------------------------------------------------------------
  // Token management
  // ---------------------------------------------------------------------------

  /// Persist the JWT so it survives app restarts.
  ///
  /// On web, flutter_secure_storage may not persist reliably, so we also
  /// store a copy in SharedPreferences as a fallback.
  Future<void> saveToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (_) {}
    // Fallback for web — SharedPreferences works reliably on web
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsTokenKey, token);
      } catch (_) {}
    }
  }

  /// Retrieve the stored JWT, or `null` if the user is not logged in.
  Future<String?> getToken() async {
    // Try secure storage first
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      if (token != null) return token;
    } catch (_) {}
    // Fallback to SharedPreferences (especially for web)
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_prefsTokenKey);
      } catch (_) {}
    }
    return null;
  }

  /// Remove the stored JWT (logout).
  Future<void> deleteToken() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (_) {}
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsTokenKey);
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// POST /register
  ///
  /// Returns the decoded JSON on success, throws an [ApiException] on failure.
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required List<String> preferences,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.register}');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'preferences': preferences,
      }),
    );

    final body = _decode(response);
    if (response.statusCode == 201) return body;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  /// POST /login
  ///
  /// On success the JWT is automatically saved and returned.
  Future<String> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    final body = _decode(response);
    if (response.statusCode == 200) {
      final token = body['token'] as String;
      await saveToken(token);
      return token;
    }
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  // ---------------------------------------------------------------------------
  // Destinations (public)
  // ---------------------------------------------------------------------------

  /// GET /destinations with optional [tag] and [maxCost] filters.
  Future<List<dynamic>> getDestinations({String? tag, int? maxCost}) async {
    final params = <String, String>{};
    if (tag != null && tag.isNotEmpty) params['tag'] = tag;
    if (maxCost != null) params['max_cost'] = maxCost.toString();

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.destinations}',
    ).replace(queryParameters: params.isNotEmpty ? params : null);

    final response = await http.get(uri);
    final body = _decode(response);
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  // ---------------------------------------------------------------------------
  // Recommendations (protected)
  // ---------------------------------------------------------------------------

  /// GET /recommendations with optional [limit].
  Future<List<dynamic>> getRecommendations({int limit = 5}) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Authentication required');

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.recommendations}',
    ).replace(queryParameters: {'limit': limit.toString()});

    final response = await http.get(uri, headers: _authHeaders(token));

    final body = _decode(response);
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  // ---------------------------------------------------------------------------
  // Itineraries (protected)
  // ---------------------------------------------------------------------------

  /// GET /itineraries – list all itineraries for the logged-in user.
  Future<List<dynamic>> getItineraries() async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Authentication required');

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.itineraries}');
    final response = await http.get(uri, headers: _authHeaders(token));

    final body = _decode(response);
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  /// POST /itineraries – create a new itinerary.
  Future<Map<String, dynamic>> createItinerary({
    required String title,
    required List<String> destinations,
    required String startDate,
    required String endDate,
    String notes = '',
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Authentication required');

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.itineraries}');
    final response = await http.post(
      uri,
      headers: {..._authHeaders(token), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'destinations': destinations,
        'start_date': startDate,
        'end_date': endDate,
        'notes': notes,
      }),
    );

    final body = _decode(response);
    if (response.statusCode == 201) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  // ---------------------------------------------------------------------------
  // Favorites (protected)
  // ---------------------------------------------------------------------------

  /// GET /favorites – list the user's favorite destination names.
  Future<List<String>> getFavorites() async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Authentication required');

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.favorites}');
    final response = await http.get(uri, headers: _authHeaders(token));

    final body = _decode(response);
    if (response.statusCode == 200) {
      return (body as List<dynamic>).cast<String>();
    }
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  /// POST /favorites – toggle a destination in the user's favorites.
  ///
  /// Returns the updated list of favorite destination names.
  Future<List<String>> toggleFavorite(String destinationName) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Authentication required');

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.favorites}');
    final response = await http.post(
      uri,
      headers: {..._authHeaders(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'destination': destinationName}),
    );

    final body = _decode(response);
    if (response.statusCode == 200) {
      return (body as List<dynamic>).cast<String>();
    }
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Bearer $token',
  };

  dynamic _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {'error': 'Unexpected server response'};
    }
  }

  String _errorMessage(dynamic body) {
    if (body is Map && body.containsKey('error')) {
      return body['error'] as String;
    }
    return 'An unexpected error occurred';
  }
}

/// Thrown when the API returns a non-success status code.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}
