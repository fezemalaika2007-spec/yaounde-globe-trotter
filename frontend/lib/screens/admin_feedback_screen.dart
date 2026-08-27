import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  List<Map<String, dynamic>> _feedbackList = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all'; // all, unresolved, resolved

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final list = await ApiService().getAllFeedback();
      if (mounted) {
        setState(() {
          _feedbackList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resolve(String id) async {
    try {
      await ApiService().resolveFeedback(id);
      if (mounted) {
        setState(() {
          final idx = _feedbackList.indexWhere((f) => f['id'] == id);
          if (idx != -1) {
            _feedbackList[idx]['is_resolved'] = 1;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as resolved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resolving: $e')),
        );
      }
    }
  }

  Color _getCategoryColor(String? cat) {
    switch (cat) {
      case 'bug':
        return Colors.redAccent;
      case 'suggestion':
        return Colors.amber.shade700;
      default:
        return Colors.blueAccent;
    }
  }

  IconData _getCategoryIcon(String? cat) {
    switch (cat) {
      case 'bug':
        return Icons.bug_report_rounded;
      case 'suggestion':
        return Icons.lightbulb_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = _feedbackList.where((f) {
      if (_filter == 'unresolved') return (f['is_resolved'] ?? 0) == 0;
      if (_filter == 'resolved') return (f['is_resolved'] ?? 0) == 1;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin — User Feedback & Bugs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFeedback,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilterChip(
                  label: Text('All (${_feedbackList.length})'),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(
                    'Unresolved (${_feedbackList.where((f) => (f['is_resolved'] ?? 0) == 0).length})',
                  ),
                  selected: _filter == 'unresolved',
                  onSelected: (_) => setState(() => _filter = 'unresolved'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(
                    'Resolved (${_feedbackList.where((f) => (f['is_resolved'] ?? 0) == 1).length})',
                  ),
                  selected: _filter == 'resolved',
                  onSelected: (_) => setState(() => _filter = 'resolved'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Main List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadFeedback,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_rounded, size: 56, color: theme.disabledColor),
                                const SizedBox(height: 12),
                                Text('No feedback entries found', style: theme.textTheme.titleMedium),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: filtered.length,
                            separatorBuilder: (c, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final isResolved = (item['is_resolved'] ?? 0) == 1;
                              final cat = item['category'] as String?;
                              final dateStr = item['created_at'] != null
                                  ? item['created_at'].toString().split('T').first
                                  : '';

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isResolved ? Colors.green.withValues(alpha: 0.5) : theme.dividerColor,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top row: category badge + user info + date
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getCategoryColor(cat).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(_getCategoryIcon(cat), size: 14, color: _getCategoryColor(cat)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      (cat ?? 'feedback').toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: _getCategoryColor(cat),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'by @${item['username'] ?? 'unknown'}',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            dateStr,
                                            style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      // Subject
                                      Text(
                                        item['subject'] ?? 'No Subject',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      // Message
                                      Text(
                                        item['message'] ?? '',
                                        style: theme.textTheme.bodyMedium,
                                      ),

                                      const SizedBox(height: 12),

                                      // Actions bar
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (isResolved)
                                            Chip(
                                              avatar: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                                              label: const Text('Resolved'),
                                              backgroundColor: Colors.green.withValues(alpha: 0.1),
                                            )
                                          else
                                            OutlinedButton.icon(
                                              onPressed: () => _resolve(item['id']),
                                              icon: const Icon(Icons.check_rounded, size: 18),
                                              label: const Text('Mark as Resolved'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.green,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
