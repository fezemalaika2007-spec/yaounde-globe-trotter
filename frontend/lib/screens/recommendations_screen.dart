import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../widgets/destination_grid.dart';
import '../widgets/empty_state.dart';

/// Recommendations page — shows live recommendations from the backend.
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
  List<dynamic> _recommendations = [];

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
      final results = await _api.getRecommendations(limit: 6);
      if (mounted) {
        setState(() {
          _recommendations = _deduplicateRecommendations(results);
        });
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to load recommendations');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _deduplicateRecommendations(List<dynamic> results) {
    final seenKeys = <String>{};
    final unique = <dynamic>[];
    for (final destination in results) {
      if (destination is! Map<String, dynamic>) continue;
      if (!_isRecommendationValid(destination)) continue;
      final key = _normalizeDestinationKey(destination);
      if (key.isEmpty || seenKeys.contains(key)) continue;
      seenKeys.add(key);
      unique.add(destination);
    }
    return unique;
  }

  bool _isRecommendationValid(Map<String, dynamic> destination) {
    final name = (destination['name'] ?? '').toString().trim();
    if (name.isEmpty) return false;
    final normalized = name.toLowerCase();
    final badPatterns = [
      'unnamed',
      'no name',
      'road',
      'street',
      'path',
      'route',
      'way',
      'voie',
      'chemin',
      'ligne',
      'line',
      'unknown',
      'null',
      'drainage',
      'track',
      'roundabout',
      'bridge',
      'interchange',
    ];
    if (badPatterns.any(normalized.contains)) return false;

    final desc = (destination['description'] ?? '').toString().trim();
    if (desc.isNotEmpty && desc.length < 20) return false;

    return true;
  }

  String _normalizeDestinationKey(Map<String, dynamic> destination) {
    final id = destination['id']?.toString().trim();
    if (id?.isNotEmpty == true) return id!;

    final name = (destination['name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    }

    return (destination['image'] ?? '').toString().trim();
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

    if (_recommendations.isEmpty) {
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
                l10n.personalizedForYou,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.recommendationsPlaceholder,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            DestinationGrid(
              destinations: _recommendations.cast<Map<String, dynamic>>(),
            ),
          ],
        ),
      ),
    );
  }
}
