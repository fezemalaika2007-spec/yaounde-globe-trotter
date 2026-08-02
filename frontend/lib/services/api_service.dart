import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/api_config.dart';

/// Centralized service for all HTTP calls to the GlobeTrotter backend.
class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _tokenKey = 'jwt_token';
  static const String _prefsTokenKey = 'jwt_token_prefs';

  /// Hard upper bound for any single HTTP request. Prevents the UI from
  /// hanging forever on a slow/unreachable backend — the user gets a clear
  /// timeout error instead of an infinite spinner.
  static const Duration _requestTimeout = Duration(seconds: 6);

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) {
    return http
        .get(uri, headers: headers)
        .timeout(
          _requestTimeout,
          onTimeout: () => throw ApiException(
            408,
            'Request timed out. Is the server running?',
          ),
        );
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http
        .post(uri, headers: headers, body: body)
        .timeout(
          _requestTimeout,
          onTimeout: () => throw ApiException(
            408,
            'Request timed out. Is the server running?',
          ),
        );
  }

  // Token management
  //
  // NOTE: FlutterSecureStorage on web can hang during WebCrypto / IndexedDB
  // plugin initialization. Every secure-storage call is therefore bounded
  // with a short timeout so a frozen storage backend can never block the
  // UI (startup auth check, login, logout, etc.). On timeout we fall back
  // to the SharedPreferences copy (kept in sync on web) or null, so the
  // app always stays responsive.
  Future<void> saveToken(String token) async {
    try {
      await _secureStorage
          .write(key: _tokenKey, value: token)
          .timeout(const Duration(milliseconds: 1500), onTimeout: () {});
    } catch (_) {}
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsTokenKey, token);
      } catch (_) {}
    }
  }

  Future<String?> getToken() async {
    try {
      final token = await _secureStorage
          .read(key: _tokenKey)
          .timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
      if (token != null) return token;
    } catch (_) {}
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_prefsTokenKey);
      } catch (_) {}
    }
    return null;
  }

  Future<void> deleteToken() async {
    try {
      await _secureStorage
          .delete(key: _tokenKey)
          .timeout(const Duration(milliseconds: 1500), onTimeout: () {});
    } catch (_) {}
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsTokenKey);
      } catch (_) {}
    }
  }

  // Auth
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required List<String> preferences,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.register}');
    final response = await _post(
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

  Future<String> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}');
    final response = await _post(
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

  // Destinations
  Future<List<dynamic>> getDestinations({String? tag, int? maxCost}) async {
    final params = <String, String>{};
    if (tag != null && tag.isNotEmpty) params['tag'] = tag;
    if (maxCost != null) params['max_cost'] = maxCost.toString();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.destinations}',
    ).replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await _get(uri);
    final body = _decode(response);
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  // Recommendations
  Future<List<dynamic>> getRecommendations({int limit = 5}) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Authentication required');
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.recommendations}',
    ).replace(queryParameters: {'limit': limit.toString()});
    final response = await _get(uri, headers: _authHeaders(token));
    final body = _decode(response);
    if (response.statusCode == 200) {
      if (body is Map && body.containsKey('recommendations')) {
        final recommendations = body['recommendations'];
        if (recommendations is List<dynamic>) {
          return recommendations;
        }
      }
      if (body is List<dynamic>) return body;
      throw ApiException(
        response.statusCode,
        'Unexpected recommendations format',
      );
    }
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  // Itineraries
  Future<List<dynamic>> getItineraries() async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Authentication required');
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.itineraries}');
    final response = await _get(uri, headers: _authHeaders(token));
    final body = _decode(response);
    if (response.statusCode == 200) return body as List<dynamic>;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

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
    final response = await _post(
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

  // Ratings
  /// POST /destinations/[id]/rating – submit or update a rating.
  /// [rating] must be 1-5.
  Future<Map<String, dynamic>> submitRating({
    required String destinationId,
    required int rating,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Authentication required');
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/destinations/$destinationId/rating',
    );
    final response = await _post(
      uri,
      headers: {..._authHeaders(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'rating': rating}),
    );
    final body = _decode(response);
    if (response.statusCode == 200) return body as Map<String, dynamic>;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  // Favorites
  Future<List<String>> getFavorites() async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Authentication required');
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.favorites}');
    final response = await _get(uri, headers: _authHeaders(token));
    final body = _decode(response);
    if (response.statusCode == 200) {
      if (body is List<dynamic>) {
        return body.cast<String>();
      }
      if (body is Map && body.containsKey('favorites')) {
        final favorites = body['favorites'];
        if (favorites is List<dynamic>) {
          return favorites.cast<String>();
        }
      }
      throw ApiException(response.statusCode, 'Unexpected favorites format');
    }
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  Future<List<String>> toggleFavorite(String destinationName) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Authentication required');
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.favorites}');
    final response = await _post(
      uri,
      headers: {..._authHeaders(token), 'Content-Type': 'application/json'},
      body: jsonEncode({'destination': destinationName}),
    );
    final body = _decode(response);
    if (response.statusCode == 200) {
      if (body is List<dynamic>) {
        return body.cast<String>();
      }
      if (body is Map && body.containsKey('favorites')) {
        final favorites = body['favorites'];
        if (favorites is List<dynamic>) {
          return favorites.cast<String>();
        }
      }
      throw ApiException(response.statusCode, 'Unexpected favorites format');
    }
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  // Helpers
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

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}
