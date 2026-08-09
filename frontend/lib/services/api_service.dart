import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/api_config.dart';

/// A structured recommendation section returned by the backend.
class RecommendationSection {
  final String title;
  final String type;
  final List<Map<String, dynamic>> items;
  const RecommendationSection({
    required this.title,
    required this.type,
    required this.items,
  });
}

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
  static const Duration _requestTimeout = Duration(seconds: 25);

  /// Wraps a [Future] HTTP call so that connection errors (server down /
  /// unreachable) and timeouts produce clear, actionable `ApiException`s
  /// instead of cryptic socket errors.
  Future<http.Response> _guard(Future<http.Response> future) async {
    try {
      return await future.timeout(
        _requestTimeout,
        onTimeout: () => throw const _TimeoutSignal(),
      );
    } on ApiException {
      rethrow;
    } on _TimeoutSignal {
      throw ApiException(
        408,
        'Connection timed out. Please check that the server is running '
        'and reachable.',
      );
    } on http.ClientException {
      throw ApiException(
        0,
        'Could not reach the server. Is it running? Check that the backend '
        'is started and the API URL is correct.',
      );
    } catch (e) {
      throw ApiException(
        0,
        'Could not connect to the server. Please try again. ($e)',
      );
    }
  }

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) {
    return _guard(http.get(uri, headers: headers));
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _guard(http.post(uri, headers: headers, body: body));
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
    required String email,
    required String password,
    required List<String> preferences,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.register}');
    final response = await _post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'preferences': preferences,
      }),
    );
    final body = _decode(response);
    if (response.statusCode == 201) return body;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  /// Verify a freshly-registered user's email with the 6-digit code.
  Future<Map<String, dynamic>> verifyEmail({
    required String username,
    required String code,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.verify}');
    final response = await _post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'code': code}),
    );
    final body = _decode(response);
    if (response.statusCode == 200) return body;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  /// Request a new email verification code.
  Future<Map<String, dynamic>> resendVerificationCode(String identifier) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.resendCode}');
    final response = await _post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': identifier}),
    );
    final body = _decode(response);
    if (response.statusCode == 200) return body;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  /// Request a password reset code to be sent via email.
  Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.forgotPassword}');
    final response = await _post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': identifier}),
    );
    final body = _decode(response);
    if (response.statusCode == 200) return body;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  /// Complete password reset using the code sent to email.
  Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.resetPassword}');
    final response = await _post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': identifier,
        'code': code,
        'password': newPassword,
      }),
    );
    final body = _decode(response);
    if (response.statusCode == 200) return body;
    throw ApiException(response.statusCode, _errorMessage(body));
  }

  /// Authenticate with a Google ID token or Access token. Returns the JWT.
  Future<String> googleLogin({String? idToken, String? accessToken}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.googleAuth}');
    final bodyData = <String, String>{};
    if (idToken != null && idToken.isNotEmpty) bodyData['id_token'] = idToken;
    if (accessToken != null && accessToken.isNotEmpty) bodyData['access_token'] = accessToken;

    final response = await _post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyData),
    );
    final body = _decode(response);
    if (response.statusCode == 200) {
      final token = body['token'] as String;
      await saveToken(token);
      return token;
    }
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

  /// Live internet search for destinations in Yaoundé.
  ///
  /// Queries the backend `/search` endpoint, which live-searches Foursquare
  /// for places matching [query] whose names match a real, photo-bearing
  /// Yaoundé destination. This lets users find places that are not yet in the
  /// local database.
  Future<List<dynamic>> searchDestinations(
    String query, {
    int limit = 12,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.search}',
    ).replace(queryParameters: {'q': trimmed, 'limit': limit.toString()});
    final response = await _get(uri);
    final body = _decode(response);
    if (response.statusCode == 200) {
      if (body is List<dynamic>) return body;
      if (body is Map &&
          body.containsKey('results') &&
          body['results'] is List) {
        return body['results'] as List<dynamic>;
      }
      throw ApiException(
        response.statusCode,
        'Unexpected search results format',
      );
    }
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

  /// Returns structured recommendation sections from the backend.
  ///
  /// The backend returns a categorized object:
  ///     { "sections": [ {"title": ..., "type": ..., "items": [...]}, ... ],
  ///       "most_popular": [...], "highly_rated": [...],
  ///       "recently_added": [...], "less_costly": [...], ...,
  ///       "recommendations": [...] }
  /// Each destination is a `Map<String, dynamic>`. This method parses the
  /// named category keys into [RecommendationSection] objects for the UI.
  Future<List<RecommendationSection>> getRecommendationSections({
    int limit = 5,
  }) async {
    final token = await getToken();
    if (token == null) throw ApiException(401, 'Authentication required');
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.recommendations}',
    ).replace(queryParameters: {'limit': limit.toString()});
    final response = await _get(uri, headers: _authHeaders(token));
    final body = _decode(response);
    if (response.statusCode == 200) {
      // Prefer the named category keys (most_popular, highly_rated, ...).
      const namedCategories = <String, String>{
        'most_popular': 'Most Popular',
        'highly_rated': 'Highly Rated',
        'recently_added': 'Recently Added',
        'less_costly': 'Less Costly',
        'food_markets': 'Food & Markets',
        'nature_parks': 'Nature & Parks',
      };
      if (body is Map) {
        final namedSections = <RecommendationSection>[];
        for (final entry in namedCategories.entries) {
          final raw = body[entry.key];
          if (raw is List<dynamic> && raw.isNotEmpty) {
            final items = <Map<String, dynamic>>[];
            for (final item in raw) {
              if (item is Map) {
                items.add(Map<String, dynamic>.from(item));
              }
            }
            if (items.isNotEmpty) {
              namedSections.add(
                RecommendationSection(
                  title: entry.value,
                  type: entry.key,
                  items: items,
                ),
              );
            }
          }
        }
        // If we found named categories, also include any generic category
        // sections from the `sections` list that aren't already covered.
        if (namedSections.isNotEmpty && body.containsKey('sections')) {
          final sectionsRaw = body['sections'];
          if (sectionsRaw is List<dynamic>) {
            final existingTypes = namedSections.map((s) => s.type).toSet();
            for (final raw in sectionsRaw) {
              if (raw is Map == false) continue;
              final title = (raw['title'] ?? '').toString();
              final type = (raw['type'] ?? '').toString();
              if (existingTypes.contains(type)) continue;
              final items = <Map<String, dynamic>>[];
              final itemsRaw = raw['items'];
              if (itemsRaw is List<dynamic>) {
                for (final item in itemsRaw) {
                  if (item is Map) {
                    items.add(Map<String, dynamic>.from(item));
                  }
                }
              }
              if (title.isNotEmpty && items.isNotEmpty) {
                namedSections.add(
                  RecommendationSection(title: title, type: type, items: items),
                );
              }
            }
          }
        }
        if (namedSections.isNotEmpty) return namedSections;
      }
      if (body is Map && body.containsKey('sections')) {
        final sectionsRaw = body['sections'];
        if (sectionsRaw is List<dynamic>) {
          final sections = <RecommendationSection>[];
          for (final raw in sectionsRaw) {
            if (raw is Map == false) continue;
            final title = (raw['title'] ?? '').toString();
            final type = (raw['type'] ?? '').toString();
            final items = <Map<String, dynamic>>[];
            final itemsRaw = raw['items'];
            if (itemsRaw is List<dynamic>) {
              for (final item in itemsRaw) {
                if (item is Map) {
                  items.add(Map<String, dynamic>.from(item));
                }
              }
            }
            if (title.isNotEmpty && items.isNotEmpty) {
              sections.add(
                RecommendationSection(title: title, type: type, items: items),
              );
            }
          }
          return sections;
        }
      } else if (body is List<dynamic>) {
        // Backward-compat: a plain list of destinations.
        final flat = <Map<String, dynamic>>[];
        for (final item in body) {
          if (item is Map) flat.add(Map<String, dynamic>.from(item));
        }
        if (flat.isNotEmpty) {
          return [
            RecommendationSection(
              title: 'Recommended for You',
              type: 'flat',
              items: flat,
            ),
          ];
        }
      }
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

/// Internal marker used to distinguish an HTTP request timeout from other
/// errors inside [_guard]. Not exposed outside this library.
class _TimeoutSignal implements Exception {
  const _TimeoutSignal();
}
