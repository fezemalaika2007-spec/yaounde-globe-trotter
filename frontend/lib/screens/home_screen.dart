import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_provider.dart';
import '../utils/image_paths.dart';
import '../widgets/app_footer.dart';
import '../widgets/asset_image.dart';

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
              // --- Hero Banner ---
              SizedBox(
                width: double.infinity,
                height: 280,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AssetImageWidget(
                      path: ImagePaths.homeHero(0),
                      width: double.infinity,
                      height: 280,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.landscape,
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
                                  blurRadius: 0.0,
                                  color: Colors.black,
                                ),
                                Shadow(
                                  offset: Offset(1, 0),
                                  blurRadius: 0.0,
                                  color: Colors.black,
                                ),
                                Shadow(
                                  offset: Offset(-1, 0),
                                  blurRadius: 0.0,
                                  color: Colors.black,
                                ),
                                Shadow(
                                  offset: Offset(0, -1),
                                  blurRadius: 0.0,
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
                                  blurRadius: 0.0,
                                  color: Colors.black,
                                ),
                                Shadow(
                                  offset: Offset(1, 0),
                                  blurRadius: 0.0,
                                  color: Colors.black,
                                ),
                                Shadow(
                                  offset: Offset(-1, 0),
                                  blurRadius: 0.0,
                                  color: Colors.black,
                                ),
                                Shadow(
                                  offset: Offset(0, -1),
                                  blurRadius: 0.0,
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
                child: const Column(
                  children: [
                    _FeatureCard(
                      icon: Icons.explore,
                      title: 'Discover Destinations',
                      description:
                          'Browse Yaoundé\'s top attractions — from Mont Fébé to Mefou National Park — with photos, ratings, costs, and tags.',
                      tabIndex: 1,
                    ),
                    _FeatureCard(
                      icon: Icons.star,
                      title: 'Get Personalized Recommendations',
                      description:
                          'Let our smart matching engine suggest destinations based on your interests and preferences.',
                      tabIndex: 2,
                    ),
                    _FeatureCard(
                      icon: Icons.map,
                      title: 'Plan & Manage Itineraries',
                      description:
                          'Create custom trip itineraries, add destinations, set dates, and keep all your travel plans in one place.',
                      tabIndex: 4,
                    ),
                    _FeatureCard(
                      icon: Icons.favorite,
                      title: 'Save Your Favorites',
                      description:
                          'Bookmark destinations you love and find them quickly in your favorites list.',
                      tabIndex: 3,
                    ),
                  ],
                ),
              ),

              // --- Supporting Images (just a few, not a full gallery) ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                child: Text(
                  l10n.homeGlimpseYaounde,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 180,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _SupportingImage(
                        path: ImagePaths.homeHero(1),
                        label: 'Yaoundé Cityscape',
                      ),
                      _SupportingImage(
                        path: ImagePaths.homeHero(2),
                        label: 'Local Culture',
                      ),
                      _SupportingImage(
                        path: ImagePaths.homeHero(3),
                        label: 'Nature & Wildlife',
                      ),
                      _SupportingImage(
                        path: ImagePaths.homeHero(4),
                        label: 'Historic Landmarks',
                      ),
                    ],
                  ),
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
                      onPressed: () => widget.onSwitchTab?.call(3),
                      icon: const Icon(Icons.favorite_border),
                      label: Text(l10n.favorites),
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
              AppFooter(
                onNavigate: widget.onSwitchTab,
                onLogout: () => AuthProvider().logout(),
              ),
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
  final int tabIndex;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tabIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Navigate to the relevant tab
          // We use a callback pattern via the widget tree
        },
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

/// A small supporting image with a label overlay.
class _SupportingImage extends StatelessWidget {
  final String path;
  final String label;

  const _SupportingImage({required this.path, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AssetImageWidget(
              path: path,
              fit: BoxFit.cover,
              fallbackIcon: Icons.landscape,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 0.0,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
