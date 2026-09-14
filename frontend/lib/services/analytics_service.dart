// ignore_for_file: use_null_aware_elements
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../firebase_options.dart';

/// Service managing Firebase Analytics and tracking application metrics.
///
/// Analytics run silently in the background and stream events directly
/// to Firebase. Aggregated counts are maintained for the app analytics dashboard.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  AnalyticsService._();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  FirebaseAnalyticsObserver? get observer => _observer;

  // Real-time metric counters for dashboard
  int _appOpensCount = 0;
  int _loginCount = 0;
  int _signUpCount = 0;
  int _searchCount = 0;
  int _destinationViewsCount = 0;
  int _itinerariesCreatedCount = 0;
  int _itinerariesDeletedCount = 0;
  int _feedbackSubmittedCount = 0;
  int _favoritesToggledCount = 0;

  final Map<String, int> _topSearchTerms = {};
  final Map<String, int> _viewedDestinations = {};
  final Map<String, int> _viewedCategories = {};
  final Map<String, int> _itineraryPaces = {};
  final List<Map<String, String>> _recentEventLogs = [];

  // Getters for Dashboard
  int get appOpensCount => _appOpensCount;
  int get loginCount => _loginCount;
  int get signUpCount => _signUpCount;
  int get searchCount => _searchCount;
  int get destinationViewsCount => _destinationViewsCount;
  int get itinerariesCreatedCount => _itinerariesCreatedCount;
  int get itinerariesDeletedCount => _itinerariesDeletedCount;
  int get feedbackSubmittedCount => _feedbackSubmittedCount;
  int get favoritesToggledCount => _favoritesToggledCount;

  Map<String, int> get topSearchTerms => Map.unmodifiable(_topSearchTerms);
  Map<String, int> get viewedDestinations => Map.unmodifiable(_viewedDestinations);
  Map<String, int> get viewedCategories => Map.unmodifiable(_viewedCategories);
  Map<String, int> get itineraryPaces => Map.unmodifiable(_itineraryPaces);
  List<Map<String, String>> get recentEventLogs => List.unmodifiable(_recentEventLogs);

  /// Initializes Firebase and Firebase Analytics safely.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      _isInitialized = true;
      debugPrint('[AnalyticsService] Firebase Analytics initialized successfully.');

      // Log App Open automatically
      await logAppOpen();
    } catch (e, stackTrace) {
      debugPrint('[AnalyticsService] Firebase initialization notice: $e');
      debugPrintStack(stackTrace: stackTrace);
      // Graceful fallback: App functions normally even if Firebase options are missing
    }
  }

  void _recordEventLocally(String eventName, Map<String, String> params) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _recentEventLogs.insert(0, {
      'timestamp': timestamp,
      'event': eventName,
      'details': params.values.join(' • '),
    });
    if (_recentEventLogs.length > 50) {
      _recentEventLogs.removeLast();
    }
  }

  /// Logs app open event.
  Future<void> logAppOpen() async {
    _appOpensCount++;
    _recordEventLocally('app_open', {'time': DateTime.now().toString()});
    try {
      await _analytics?.logAppOpen();
    } catch (e) {
      debugPrint('[AnalyticsService] logAppOpen failed: $e');
    }
  }

  /// Logs user login event.
  Future<void> logLogin({required String method}) async {
    _loginCount++;
    _recordEventLocally('login', {'method': method});
    try {
      await _analytics?.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('[AnalyticsService] logLogin failed: $e');
    }
  }

  /// Logs user sign up event.
  Future<void> logSignUp({required String method}) async {
    _signUpCount++;
    _recordEventLocally('sign_up', {'method': method});
    try {
      await _analytics?.logSignUp(signUpMethod: method);
    } catch (e) {
      debugPrint('[AnalyticsService] logSignUp failed: $e');
    }
  }

  /// Logs user logout event.
  Future<void> logLogout() async {
    _recordEventLocally('logout', {'status': 'user_logged_out'});
    try {
      await _analytics?.logEvent(name: 'logout');
    } catch (e) {
      debugPrint('[AnalyticsService] logLogout failed: $e');
    }
  }

  /// Logs free text destination search queries.
  Future<void> logSearch({required String searchTerm}) async {
    if (searchTerm.trim().isEmpty) return;
    _searchCount++;
    final term = searchTerm.trim().toLowerCase();
    _topSearchTerms[term] = (_topSearchTerms[term] ?? 0) + 1;
    _recordEventLocally('search', {'term': searchTerm});
    try {
      await _analytics?.logSearch(searchTerm: searchTerm);
    } catch (e) {
      debugPrint('[AnalyticsService] logSearch failed: $e');
    }
  }

  /// Logs destination detail view event.
  Future<void> logViewDestination({
    required String id,
    required String name,
    String? category,
  }) async {
    _destinationViewsCount++;
    _viewedDestinations[name] = (_viewedDestinations[name] ?? 0) + 1;
    if (category != null && category.isNotEmpty) {
      _viewedCategories[category] = (_viewedCategories[category] ?? 0) + 1;
    }
    _recordEventLocally('view_destination', {
      'id': id,
      'name': name,
      if (category != null) 'category': category,
    });
    try {
      await _analytics?.logEvent(
        name: 'view_destination',
        parameters: {
          'destination_id': id,
          'destination_name': name,
          if (category != null) 'category': category,
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logViewDestination failed: $e');
    }
  }

  /// Logs destination favorite/unfavorite toggle.
  Future<void> logToggleFavorite({
    required String destinationId,
    required bool isFavorite,
  }) async {
    _favoritesToggledCount++;
    _recordEventLocally('toggle_favorite', {
      'destination_id': destinationId,
      'is_favorite': isFavorite.toString(),
    });
    try {
      await _analytics?.logEvent(
        name: isFavorite ? 'add_to_favorites' : 'remove_from_favorites',
        parameters: {'destination_id': destinationId},
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logToggleFavorite failed: $e');
    }
  }

  /// Logs itinerary generation event.
  Future<void> logGenerateItinerary({
    required int days,
    String? pace,
    String? budget,
  }) async {
    _itinerariesCreatedCount++;
    if (pace != null && pace.isNotEmpty) {
      _itineraryPaces[pace] = (_itineraryPaces[pace] ?? 0) + 1;
    }
    _recordEventLocally('generate_itinerary', {
      'days': days.toString(),
      if (pace != null) 'pace': pace,
      if (budget != null) 'budget': budget,
    });
    try {
      await _analytics?.logEvent(
        name: 'generate_itinerary',
        parameters: {
          'days': days,
          if (pace != null) 'pace': pace,
          if (budget != null) 'budget': budget,
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logGenerateItinerary failed: $e');
    }
  }

  /// Logs itinerary deletion event.
  Future<void> logDeleteItinerary({required String id}) async {
    _itinerariesDeletedCount++;
    _recordEventLocally('delete_itinerary', {'id': id});
    try {
      await _analytics?.logEvent(
        name: 'delete_itinerary',
        parameters: {'itinerary_id': id},
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logDeleteItinerary failed: $e');
    }
  }

  /// Logs live community chat message send event.
  Future<void> logSendChatMessage() async {
    _recordEventLocally('send_chat_message', {'status': 'success'});
    try {
      await _analytics?.logEvent(name: 'send_chat_message');
    } catch (e) {
      debugPrint('[AnalyticsService] logSendChatMessage failed: $e');
    }
  }

  /// Logs user feedback submission.
  Future<void> logSubmitFeedback({
    required String category,
    int? rating,
  }) async {
    _feedbackSubmittedCount++;
    _recordEventLocally('submit_feedback', {
      'category': category,
      if (rating != null) 'rating': rating.toString(),
    });
    try {
      await _analytics?.logEvent(
        name: 'submit_feedback',
        parameters: {
          'category': category,
          if (rating != null) 'rating': rating,
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logSubmitFeedback failed: $e');
    }
  }

  /// Logs viewing recommendations section.
  Future<void> logViewRecommendations() async {
    _recordEventLocally('view_recommendations', {'time': DateTime.now().toString()});
    try {
      await _analytics?.logEvent(name: 'view_recommendations');
    } catch (e) {
      debugPrint('[AnalyticsService] logViewRecommendations failed: $e');
    }
  }

  /// Logs theme preference change.
  Future<void> logChangeTheme({required String themeMode}) async {
    _recordEventLocally('change_theme', {'theme': themeMode});
    try {
      await _analytics?.logEvent(
        name: 'change_theme',
        parameters: {'theme_mode': themeMode},
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logChangeTheme failed: $e');
    }
  }

  /// Logs language locale change.
  Future<void> logChangeLanguage({required String languageCode}) async {
    _recordEventLocally('change_language', {'locale': languageCode});
    try {
      await _analytics?.logEvent(
        name: 'change_language',
        parameters: {'language_code': languageCode},
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logChangeLanguage failed: $e');
    }
  }
}
