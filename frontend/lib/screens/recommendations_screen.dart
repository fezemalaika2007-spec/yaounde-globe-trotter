import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/image_paths.dart';
import '../widgets/destination_card.dart';
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
      final data = await _api.getRecommendations();
      if (mounted) setState(() => _recommendations = data);
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
                    return DestinationCard(
                      imagePath: ImagePaths.recommendation(i),
                      name: r['name'] ?? '',
                      country: r['country'] ?? '',
                      cost: r['avg_cost_per_day'],
                      tags: r['tags'] ?? [],
                      description: r['description'],
                      trailing: Chip(
                        label: Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: score > 0
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                        backgroundColor: score > 0
                            ? theme.colorScheme.primary
                            : Colors.grey.shade300,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
