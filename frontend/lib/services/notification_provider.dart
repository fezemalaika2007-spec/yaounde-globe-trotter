import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class NotificationProvider extends ChangeNotifier {
  static final NotificationProvider _instance = NotificationProvider._();
  factory NotificationProvider() => _instance;
  NotificationProvider._();

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  Timer? _pollingTimer;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void startPolling() {
    fetchNotifications();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchNotifications();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> fetchNotifications() async {
    try {
      _isLoading = true;
      final res = await ApiService().getNotifications();
      if (res['notifications'] is List) {
        _notifications = List<Map<String, dynamic>>.from(res['notifications']);
      }
      _unreadCount = (res['unread_count'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> markAsRead(String notifId) async {
    try {
      await ApiService().markNotificationRead(notifId);
      final idx = _notifications.indexWhere((n) => n['id'] == notifId);
      if (idx != -1) {
        if ((_notifications[idx]['is_read'] ?? 0) == 0) {
          _unreadCount = (_unreadCount - 1).clamp(0, 999);
        }
        _notifications[idx]['is_read'] = 1;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await ApiService().markAllNotificationsRead();
      for (var n in _notifications) {
        n['is_read'] = 1;
      }
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
    }
  }
}
