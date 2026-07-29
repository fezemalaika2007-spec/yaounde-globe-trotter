import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Recommendations page — currently shows a placeholder state.
///
/// This page will later be rebuilt to automatically generate personalized
/// recommendations based on how often a user searches for specific places,
/// what they favourite/like, and what's generally popular and matches their
/// taste. For now, a clean placeholder is shown.
class RecommendationsScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const RecommendationsScreen({super.key, required this.onLocaleChanged});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.recommendationsComingSoon,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.recommendationsPlaceholder,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
