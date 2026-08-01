import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

import '../widgets/app_footer.dart';

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
      // Pull a few real destinations from the API for the home screen.
      // Bounded with a timeout so a slow/unreachable backend never leaves
      // the home page janky — the rest of the page renders regardless.
      final destinations = await _api.getDestinations().timeout(
        const Duration(seconds: 4),
      );
      if (mounted) {
        setState(() {
          // Take first 3-4 destinations to feature on home
          _featuredDestinations = destinations.take(4).toList();
        });
      }
    } catch (_) {
      // Silently handle — home will just show no featured destinations
    } finally {
      if (mounted) {
        setState(() {
          _featuredLoading = false;
        });
      }
    }
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
                    // Gradient overlay for readability
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.5),
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

              // --- Featured Destinations (from API) ---
              if (_featuredLoading || _featuredDestinations.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    l10n.featuredDestinations,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 260,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _featuredLoading
                        ? 4
                        : _featuredDestinations.length,
                    itemBuilder: (_, i) {
                      if (_featuredLoading) {
                        return SizedBox(
                          width: 280,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 140,
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 18,
                                      width: 140,
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 14,
                                      width: 90,
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final d = _featuredDestinations[i];
                      return SizedBox(
                        width: 280,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 150,
                                  width: double.infinity,
                                  child:
                                      d['image'] != null &&
                                          d['image'].toString().isNotEmpty
                                      ? Image.network(
                                          d['image'],
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (
                                                context,
                                                error,
                                                stackTrace,
                                              ) => Container(
                                                color: theme
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                child: const Icon(
                                                  Icons.place,
                                                  size: 48,
                                                ),
                                              ),
                                        )
                                      : Container(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Icon(
                                            Icons.place,
                                            size: 48,
                                          ),
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d['name'] ?? '',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            size: 16,
                                            color: Colors.amber,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${(d['average_rating'] ?? 0).toStringAsFixed(1)}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

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
                      title: 'Discover Destinations',
                      description:
                          'Browse Yaoundé\'s top attractions — from Mont Fébé to Mefou National Park — with photos, ratings, costs, and tags.',
                      onTap: () => widget.onSwitchTab?.call(1),
                    ),
                    _FeatureCard(
                      icon: Icons.star,
                      title: 'Get Personalized Recommendations',
                      description:
                          'Let our smart matching engine suggest destinations based on your interests and preferences.',
                      onTap: () => widget.onSwitchTab?.call(2),
                    ),
                    _FeatureCard(
                      icon: Icons.map,
                      title: 'Plan & Manage Itineraries',
                      description:
                          'Create custom trip itineraries, add destinations, set dates, and keep all your travel plans in one place.',
                      onTap: () => widget.onSwitchTab?.call(4),
                    ),
                    _FeatureCard(
                      icon: Icons.favorite,
                      title: 'Save Favorite Locations',
                      description:
                          'Tap the heart icon on any destination to bookmark it and build your personal travel list for easy access later.',
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
