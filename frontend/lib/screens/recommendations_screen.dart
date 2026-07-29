import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../widgets/empty_state.dart';

class RecommendationsScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const RecommendationsScreen({super.key, required this.onLocaleChanged});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _api = ApiService();
  List<dynamic> _recommendations = [];
  List<String> _favoriteNames = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getRecommendations(),
        _api.getFavorites(),
      ]);
      if (mounted) {
        setState(() {
          _recommendations = results[0];
          _favoriteNames = results[1].cast<String>();
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Failed to load recommendations');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite(String destinationName) async {
    try {
      final updated = await _api.toggleFavorite(destinationName);
      setState(() => _favoriteNames = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update favorites')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Text(
                l10n.personalizedForYou,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _fetch, child: Text(l10n.tryAgain)),
                    ],
                  ),
                )
              : _recommendations.isEmpty
              ? EmptyState(
                  icon: Icons.star_outline,
                  title: l10n.noRecommendations,
                  message: l10n.nothingHere,
                  onAction: _fetch,
                  actionLabel: l10n.refresh,
                )
              : ListView.builder(
                  itemCount: _recommendations.length,
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  itemBuilder: (_, i) {
                    final r = _recommendations[i];
                    final score = r['match_score'] ?? 0;
                    final name = r['name'] ?? '';
                    final isFav = _favoriteNames.contains(name);
                    return _TextRecommendationCard(
                      name: name,
                      country: r['country'] ?? '',
                      city: r['city'],
                      description: r['description'] ?? '',
                      tags: r['tags'] ?? [],
                      cost: r['avg_cost_per_day'],
                      duration: r['duration'],
                      matchScore: score,
                      isFavorite: isFav,
                      onFavoriteToggle: () => _toggleFavorite(name),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A text-only recommendation card — no images.
///
/// This card displays the recommended destination's name, description,
/// tags, cost, duration, and match score. Images are intentionally
/// omitted for the current version. The code is structured so that
/// images can be added later based on dynamic preference matching.
class _TextRecommendationCard extends StatelessWidget {
  final String name;
  final String country;
  final String? city;
  final String description;
  final List<dynamic> tags;
  final int? cost;
  final String? duration;
  final int matchScore;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const _TextRecommendationCard({
    required this.name,
    required this.country,
    this.city,
    required this.description,
    required this.tags,
    this.cost,
    this.duration,
    required this.matchScore,
    required this.isFavorite,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: name + match score + favorite
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                city != null ? '$city, $country' : country,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Match score badge
                  if (matchScore > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '$matchScore',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Favorite button
                  if (onFavoriteToggle != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onFavoriteToggle,
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : null,
                        size: 22,
                      ),
                      tooltip: isFavorite ? 'Favorited' : 'Add to favorites',
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Tags
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: tags
                      .map(
                        (t) => Chip(
                          label: Text(
                            '#$t',
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                      )
                      .toList(),
                ),

              const SizedBox(height: 12),

              // Info row: cost + duration
              Row(
                children: [
                  if (cost != null) ...[
                    Icon(
                      Icons.attach_money,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$cost/day',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (duration != null) ...[
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      duration!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Name + match score
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            city != null ? '$city, $country' : country,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (matchScore > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Match: $matchScore',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tags
                if (tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: tags
                        .map(
                          (t) => Chip(
                            label: Text('#$t'),
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                // Description
                Text(
                  description,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
                const SizedBox(height: 16),
                // Info
                if (cost != null)
                  _DetailRow(
                    icon: Icons.attach_money,
                    label: 'Cost',
                    value: '$cost/day',
                  ),
                if (duration != null)
                  _DetailRow(
                    icon: Icons.schedule,
                    label: 'Duration',
                    value: duration!,
                  ),
                const SizedBox(height: 24),
                // Favorite button
                if (onFavoriteToggle != null)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.tonalIcon(
                      onPressed: onFavoriteToggle,
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                      ),
                      label: Text(
                        isFavorite ? 'Favorited' : 'Add to favorites',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
