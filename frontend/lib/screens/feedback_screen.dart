import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedCategory = 'feedback';
  bool _isSubmitting = false;

  final List<Map<String, String>> _categories = [
    {'value': 'feedback', 'label': '💬 General Feedback'},
    {'value': 'bug', 'label': '🐛 Report a Bug'},
    {'value': 'suggestion', 'label': '💡 Feature Suggestion'},
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Open Gmail compose directly in a new browser tab pre-filled with
  /// the feedback addressed to fezemalaika2007@gmail.com.
  Future<void> _openGmailCompose(String subject, String message) async {
    final encodedSubject = Uri.encodeComponent(
      '[GlobeTrotter ${_selectedCategory.toUpperCase()}] $subject',
    );
    final encodedBody = Uri.encodeComponent(
      'Category: $_selectedCategory\n\n$message\n\n— Sent from GlobeTrotter App',
    );
    final gmailUrl = Uri.parse(
      'https://mail.google.com/mail/?view=cm&to=fezemalaika2007@gmail.com&su=$encodedSubject&body=$encodedBody',
    );

    try {
      await launchUrl(gmailUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fallback to mailto if Gmail web compose fails
      final mailtoUri = Uri(
        scheme: 'mailto',
        path: 'fezemalaika2007@gmail.com',
        queryParameters: {
          'subject': '[GlobeTrotter ${_selectedCategory.toUpperCase()}] $subject',
          'body': 'Category: $_selectedCategory\n\n$message\n\n— Sent from GlobeTrotter App',
        },
      );
      try {
        await launchUrl(mailtoUri);
      } catch (_) {}
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    setState(() => _isSubmitting = true);

    // 1. Try saving to backend (non-blocking — don't fail if backend is down)
    try {
      await ApiService().submitFeedback(
        category: _selectedCategory,
        subject: subject,
        message: message,
      );
      await AnalyticsService().logSubmitFeedback(category: _selectedCategory);
    } catch (_) {
      // Backend save failed — that's OK, email delivery is the priority
    }

    // 2. Open Gmail compose window — this is the PRIMARY delivery method
    await _openGmailCompose(subject, message);

    if (mounted) {
      setState(() => _isSubmitting = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_rounded, color: Colors.teal, size: 54),
          title: const Text('Almost Done!'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A Gmail compose window has been opened with your feedback pre-filled.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              Text(
                '👉 Just press "Send" in Gmail to deliver your feedback to the developer.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // return to previous screen
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback & Bug Reports'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.secondaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.rate_review_rounded, color: theme.colorScheme.onPrimaryContainer),
                        const SizedBox(width: 10),
                        Text(
                          'Help Us Improve',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your feedback will be sent via Gmail to the developer.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Category Selector
              Text('Category', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: _categories.map((c) {
                  return DropdownMenuItem(
                    value: c['value'],
                    child: Text(c['label']!),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),

              const SizedBox(height: 16),

              // Subject Field
              Text('Subject', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  hintText: 'Brief summary of the issue or feedback',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a subject';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Message Field
              Text('Details & Steps to Reproduce', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Describe the issue or feedback in detail...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your message';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSubmitting ? 'Opening Gmail...' : 'Submit Feedback via Gmail'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
