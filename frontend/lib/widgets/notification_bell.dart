import 'package:flutter/material.dart';
import '../services/notification_provider.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _notifProvider = NotificationProvider();

  @override
  void initState() {
    super.initState();
    _notifProvider.addListener(_onNotifChange);
    _notifProvider.startPolling();
  }

  void _onNotifChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notifProvider.removeListener(_onNotifChange);
    super.dispose();
  }

  void _showNotificationPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _NotificationPanelSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifProvider.unreadCount;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
          onPressed: _showNotificationPanel,
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationPanelSheet extends StatefulWidget {
  const _NotificationPanelSheet();

  @override
  State<_NotificationPanelSheet> createState() => _NotificationPanelSheetState();
}

class _NotificationPanelSheetState extends State<_NotificationPanelSheet> {
  final _notifProvider = NotificationProvider();

  @override
  void initState() {
    super.initState();
    _notifProvider.addListener(_onNotifChange);
  }

  void _onNotifChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notifProvider.removeListener(_onNotifChange);
    super.dispose();
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'rating':
        return Icons.star_rounded;
      case 'itinerary':
        return Icons.map_rounded;
      case 'feedback':
        return Icons.feedback_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getColorForType(String? type, ThemeData theme) {
    switch (type) {
      case 'rating':
        return Colors.amber;
      case 'itinerary':
        return theme.colorScheme.primary;
      case 'feedback':
        return Colors.purple;
      default:
        return theme.colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifications = _notifProvider.notifications;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded),
                    const SizedBox(width: 10),
                    Text(
                      'Notifications',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (notifications.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _notifProvider.markAllAsRead(),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Mark all read'),
                  ),
              ],
            ),
          ),

          const Divider(),

          // Notification List
          Expanded(
            child: notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 56, color: theme.disabledColor),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications yet',
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.disabledColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You\'re all caught up!',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      final isUnread = (item['is_read'] ?? 0) == 0;
                      final type = item['type'] as String?;

                      return ListTile(
                        tileColor: isUnread ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15) : null,
                        leading: CircleAvatar(
                          backgroundColor: _getColorForType(type, theme).withValues(alpha: 0.2),
                          child: Icon(_getIconForType(type), color: _getColorForType(type, theme)),
                        ),
                        title: Text(
                          item['title'] ?? 'Notification',
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item['message'] ?? ''),
                            const SizedBox(height: 4),
                            Text(
                              item['created_at'] != null
                                  ? item['created_at'].toString().split('T').first
                                  : '',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
                            ),
                          ],
                        ),
                        trailing: isUnread
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        onTap: () {
                          if (isUnread && item['id'] != null) {
                            _notifProvider.markAsRead(item['id']);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
