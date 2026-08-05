import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../widgets/destination_grid_card.dart';
import '../widgets/empty_state.dart';

/// Recommendations page — shows live, structured recommendations from the
/// backend (Top Rated, Popular Right Now, Newly Added, category sections).
class RecommendationsScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  final VoidCallback? onExplore;
  const RecommendationsScreen({
    super.key,
    required this.onLocaleChanged,
    this.onExplore,
  });

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<RecommendationSection> _sections = [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sections = await _api.getRecommendationSections(limit: 5);
      if (mounted) {
        setState(() => _sections = sections);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to load recommendations');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 58,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: _loadRecommendations,
                child: Text(l10n.refresh),
              ),
            ],
          ),
        ),
      );
    }

    if (_sections.isEmpty) {
      return EmptyState(
        icon: Icons.star_outline,
        title: l10n.noRecommendations,
        message: l10n.recommendationsPlaceholder,
        onAction: widget.onExplore,
        actionLabel: widget.onExplore != null
            ? l10n.destinations
            : l10n.refresh,
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Recommended for You',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final section in _sections) _buildSection(section),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(RecommendationSection section) {
    final theme = Theme.of(context);
    if (section.items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              section.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: section.items.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: SizedBox(
                    width: 150,
                    child: DestinationGridCard(
                      destination: section.items[index],
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
