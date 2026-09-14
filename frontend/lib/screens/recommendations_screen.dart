import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../widgets/destination_grid_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_loading.dart';

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
      final sections = await _api.getRecommendationSections(limit: 8);
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
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerGrid(count: 6),
      );
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

    return RefreshIndicator(
      onRefresh: _loadRecommendations,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Hero header ---
            _buildHeroHeader(theme),
            const SizedBox(height: 8),
            for (final section in _sections) _buildSection(section),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recommended for You',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadRecommendations,
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Curated picks based on ratings, popularity, and your preferences.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(RecommendationSection section) {
    final theme = Theme.of(context);
    if (section.items.isEmpty) return const SizedBox.shrink();

    final metric = _metricForType(section.type);
    final icon = _iconForType(section.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (metric.isNotEmpty)
                        Text(
                          metric,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${section.items.length} places',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Horizontal scrollable cards
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: section.items.length,
              itemBuilder: (context, index) {
                final item = section.items[index];
                final matchScore = _computeMatchScore(item, section.type);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: 180,
                    child: Stack(
                      children: [
                        DestinationGridCard(destination: item),
                        // Match score badge
                        if (matchScore > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _matchColor(matchScore),
                                    _matchColor(matchScore).withValues(
                                      alpha: 0.8,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.whatshot,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$matchScore%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  /// Computes a synthetic "match score" 0-100 based on the destination's
  /// rating, cost, and the section type. This gives users a visual indicator
  /// of how well this destination fits.
  int _computeMatchScore(Map<String, dynamic> item, String sectionType) {
    double score = 60; // baseline

    final avgRating = (item['average_rating'] ?? 0).toDouble();
    final ratingCount = (item['rating_count'] ?? 0).toInt();

    // Rating contribution (up to +25)
    if (avgRating > 0) {
      score += (avgRating / 5.0) * 25;
    }

    // Popularity contribution (up to +10)
    if (ratingCount > 5) {
      score += 10;
    } else if (ratingCount > 0) {
      score += 5;
    }

    // Section-type bonus
    switch (sectionType) {
      case 'highly_rated':
        score += 5;
        break;
      case 'most_popular':
        score += 3;
        break;
      default:
        break;
    }

    return score.clamp(0, 99).round();
  }

  Color _matchColor(int score) {
    if (score >= 85) return const Color(0xFF2E7D32); // green
    if (score >= 70) return const Color(0xFF1565C0); // blue
    if (score >= 50) return const Color(0xFFEF6C00); // orange
    return const Color(0xFF757575); // grey
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'most_popular':
        return Icons.trending_up;
      case 'highly_rated':
        return Icons.star;
      case 'recently_added':
        return Icons.fiber_new;
      case 'less_costly':
        return Icons.savings;
      case 'food_markets':
        return Icons.restaurant;
      case 'nature_parks':
        return Icons.park;
      default:
        return Icons.explore;
    }
  }

  /// Returns a short header label describing the ranking metric for a
  /// recommendation category, or an empty string if none applies.
  String _metricForType(String type) {
    switch (type) {
      case 'most_popular':
        return 'Most rated destinations';
      case 'highly_rated':
        return 'Top rated by visitors';
      case 'recently_added':
        return 'Newest additions';
      case 'less_costly':
        return 'Budget-friendly picks';
      case 'food_markets':
        return 'Best food & dining spots';
      case 'nature_parks':
        return 'Nature & outdoor favorites';
      default:
        return '';
    }
  }
}
