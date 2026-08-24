import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/destination_filters.dart';
import '../widgets/app_footer.dart';
import '../widgets/destination_grid.dart';

/// Callback type for requesting a tab switch from within a child widget.
typedef OnSwitchTab = void Function(int index);

class HomeScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  final OnSwitchTab? onSwitchTab;
  const HomeScreen({
    super.key,
    required this.onLocaleChanged,
    this.onSwitchTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  List<dynamic> _featuredDestinations = [];
  bool _featuredLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeatured();
  }

  Future<void> _loadFeatured() async {
    try {
      final destinations = await _api.getDestinations().timeout(
        const Duration(seconds: 4),
      );
      if (mounted) {
        setState(() {
          _featuredDestinations = _selectFeaturedDestinations(destinations);
        });
      }
    } catch (_) {
      // Silently handle — home will just show no featured destinations.
    } finally {
      if (mounted) {
        setState(() {
          _featuredLoading = false;
        });
      }
    }
  }

  List<dynamic> _selectFeaturedDestinations(List<dynamic> destinations) {
    final seenKeys = <String>{};
    final filtered = <dynamic>[];
    for (final destination in destinations) {
      if (destination is! Map<String, dynamic>) continue;
      if (!_isFeaturedDestinationValid(destination)) continue;

      final key = _normalizeDestinationKey(destination);
      if (key.isEmpty || seenKeys.contains(key)) continue;
      seenKeys.add(key);
      filtered.add(destination);
      if (filtered.length >= 4) break;
    }
    return filtered;
  }

  bool _isFeaturedDestinationValid(Map<String, dynamic> destination) {
    final name = (destination['name'] ?? '').toString().trim();
    if (name.isEmpty || !_hasGoodName(name)) return false;
    if (!_hasValidImage(destination)) return false;
    if (!_hasGoodLocation(destination)) return false;

    final desc = (destination['description'] ?? '').toString().trim();
    if (desc.isEmpty) return false;
    if (desc.length < 30) return false;

    return true;
  }

  bool _hasGoodName(String name) {
    final normalized = name.toLowerCase();
    if (normalized.length < 4) return false;
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
      'poi',
      'point of interest',
    ];
    return !badPatterns.any(normalized.contains);
  }

  bool _hasValidImage(Map<String, dynamic> destination) {
    final image = (destination['image'] ?? '').toString().trim();
    if (image.startsWith('http://') || image.startsWith('https://') || image.startsWith('assets/')) {
      return true;
    }
    final name = (destination['name'] ?? '').toString();
    return getLocalAssetFallback(name).isNotEmpty;
  }

  bool _hasGoodLocation(Map<String, dynamic> destination) {
    final area = (destination['area'] ?? '').toString().toLowerCase();
    final city = (destination['city'] ?? '').toString().toLowerCase();
    final tags = ((destination['tags'] as List<dynamic>?) ?? [])
        .map((tag) => tag.toString().toLowerCase())
        .toList();
    final name = (destination['name'] ?? '').toString().toLowerCase();

    if (area.contains('yaound') || city.contains('yaound')) return true;
    if (name.contains('yaound')) return true;
    if (tags.any((tag) => tag.contains('yaound') || tag.contains('cameroon'))) {
      return true;
    }
    return false;
  }

  String _normalizeDestinationKey(Map<String, dynamic> destination) {
    final id = destination['id']?.toString().trim();
    if (id?.isNotEmpty == true) return id!;
    final name = (destination['name'] ?? '').toString().trim();
    final image = (destination['image'] ?? '').toString().trim();
    if (name.isNotEmpty && image.isNotEmpty) {
      return '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim()}|${image.toLowerCase()}';
    }
    if (name.isNotEmpty) {
      return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    }
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Hero Banner (background image + gradient overlay) ---
              SizedBox(
                width: double.infinity,
                height: 280,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background image — upload your image to
                    // assets/images/home/hero_1.jpg
                    Image.asset(
                      'assets/images/home/hero_1.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                    // Very light gradient overlay for readability — keeps the
                    // hero image bright and clear while still letting the
                    // overlaid text stand out.
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.10),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    // Text overlay
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 36,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yaounde.Trip',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              shadows: const [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.exploreSubtitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.95),
                              shadows: const [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => widget.onSwitchTab?.call(1),
                            icon: const Icon(Icons.explore),
                            label: Text(l10n.startExploring),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- Welcome / Intro Section ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.welcomeToYaounde,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.homeIntroText,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),

              // --- Feature Cards (What you can do) ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  l10n.homeWhatYouCanDo,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _FeatureCard(
                      icon: Icons.explore,
                      title: l10n.homeFeatureDiscoverTitle,
                      description: l10n.homeFeatureDiscoverDesc,
                      onTap: () => widget.onSwitchTab?.call(1),
                    ),
                    _FeatureCard(
                      icon: Icons.star,
                      title: l10n.homeFeatureRecommendTitle,
                      description: l10n.homeFeatureRecommendDesc,
                      onTap: () => widget.onSwitchTab?.call(2),
                    ),
                    _FeatureCard(
                      icon: Icons.map,
                      title: l10n.homeFeaturePlanTitle,
                      description: l10n.homeFeaturePlanDesc,
                      onTap: () => widget.onSwitchTab?.call(4),
                    ),
                    _FeatureCard(
                      icon: Icons.favorite,
                      title: l10n.homeFeatureSaveTitle,
                      description: l10n.homeFeatureSaveDesc,
                      onTap: () => widget.onSwitchTab?.call(2),
                    ),
                  ],
                ),
              ),

              // --- Quick Navigation Buttons ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => widget.onSwitchTab?.call(1),
                      icon: const Icon(Icons.explore_outlined),
                      label: Text(l10n.destinations),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => widget.onSwitchTab?.call(2),
                      icon: const Icon(Icons.star_outline),
                      label: Text(l10n.recommendations),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => widget.onSwitchTab?.call(4),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(l10n.itineraries),
                    ),
                  ],
                ),
              ),

              // --- Featured Destinations ---
              if (_featuredLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_featuredDestinations.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                  child: Text(
                    l10n.featuredDestinations,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DestinationGrid(
                  destinations: _featuredDestinations
                      .cast<Map<String, dynamic>>(),
                  shrinkWrap: true,
                  scrollable: false,
                ),
              ],

              const SizedBox(height: 32),

              // --- Footer ---
              AppFooter(onNavigate: widget.onSwitchTab),
            ],
          ),
        ),
      ),
    );
  }
}

/// A feature card explaining what the user can do in the app.
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
