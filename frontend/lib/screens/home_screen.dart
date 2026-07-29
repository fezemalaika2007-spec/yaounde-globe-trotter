import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/image_paths.dart';
import '../widgets/asset_image.dart';
import '../widgets/destination_card.dart';
import '../widgets/empty_state.dart';

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
  List<dynamic> _featured = [];
  bool _loading = true;
  String? _error;
  final _pageCtrl = PageController();
  int _heroPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchFeatured();
    _startHeroAutoPlay();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startHeroAutoPlay() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _heroPage = (_heroPage + 1) % 5);
      _pageCtrl.animateToPage(
        _heroPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
      _startHeroAutoPlay();
    });
  }

  Future<void> _fetchFeatured() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.getDestinations();
      if (mounted) {
        setState(() => _featured = data.take(4).toList());
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Failed to load destinations');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Hero Banner Carousel ---
              SizedBox(
                width: double.infinity,
                height: 340,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _pageCtrl,
                      itemCount: 5,
                      onPageChanged: (i) => setState(() => _heroPage = i),
                      itemBuilder: (_, i) => AssetImageWidget(
                        path: ImagePaths.homeHero(i),
                        width: double.infinity,
                        height: 340,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.landscape,
                      ),
                    ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.4),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    // Text & Action overlay
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
                              fontWeight: FontWeight.extrabold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              shadows: [
                                const Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 6.0,
                                  color: Colors.black87,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.exploreSubtitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.95),
                              shadows: [
                                const Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 4.0,
                                  color: Colors.black87,
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
                    // Page dots
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _heroPage == i ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: _heroPage == i ? 0.95 : 0.45,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Quick Navigation Section ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.welcomeToYaounde,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.exploreSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
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
                          onPressed: () => widget.onSwitchTab?.call(3),
                          icon: const Icon(Icons.map_outlined),
                          label: Text(l10n.itineraries),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- Featured Destinations Header ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.featuredDestinations,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => widget.onSwitchTab?.call(1),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(l10n.viewAll),
                    ),
                  ],
                ),
              ),

              // --- Featured List ---
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: EmptyState(
                    icon: Icons.cloud_off,
                    title: l10n.noDestinations,
                    message: _error!,
                    onAction: _fetchFeatured,
                    actionLabel: l10n.tryAgain,
                  ),
                )
              else if (_featured.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: EmptyState(
                    icon: Icons.explore_outlined,
                    title: l10n.nothingHere,
                    message: l10n.noDestinations,
                  ),
                )
              else
                ...List.generate(_featured.length, (i) {
                  final d = _featured[i];
                  return DestinationCard(
                    imagePath: ImagePaths.destination(i),
                    name: d['name'] ?? '',
                    country: d['country'] ?? '',
                    cost: d['avg_cost_per_day'],
                    tags: d['tags'] ?? [],
                    description: d['description'],
                  );
                }),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
