import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Callback type for requesting a tab switch from within a child widget.
typedef OnSwitchTab = void Function(int index);

class HomeScreen extends StatelessWidget {
  final void Function(Locale) onLocaleChanged;
  final OnSwitchTab? onSwitchTab;
  const HomeScreen({
    super.key,
    required this.onLocaleChanged,
    this.onSwitchTab,
  });

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
                            onPressed: () => onSwitchTab?.call(1),
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
                      onTap: () => onSwitchTab?.call(1),
                    ),
                    _FeatureCard(
                      icon: Icons.star,
                      title: l10n.homeFeatureRecommendTitle,
                      description: l10n.homeFeatureRecommendDesc,
                      onTap: () => onSwitchTab?.call(2),
                    ),
                    _FeatureCard(
                      icon: Icons.map,
                      title: l10n.homeFeaturePlanTitle,
                      description: l10n.homeFeaturePlanDesc,
                      onTap: () => onSwitchTab?.call(4),
                    ),
                    _FeatureCard(
                      icon: Icons.favorite,
                      title: l10n.homeFeatureSaveTitle,
                      description: l10n.homeFeatureSaveDesc,
                      onTap: () => onSwitchTab?.call(3),
                    ),
                    const _FeatureCard(
                      icon: Icons.forum_outlined,
                      title: 'Live Community Chatroom',
                      description:
                          'Connect, chat live, and share travel tips with fellow travelers in real-time (open from the top-right 3-dots menu).',
                    ),
                    const _FeatureCard(
                      icon: Icons.feedback_outlined,
                      title: 'Feedback & Bug Reporting',
                      description:
                          'Submit app feedback, report issues, and send feature suggestions directly to the developer team.',
                    ),
                    const _FeatureCard(
                      icon: Icons.analytics_outlined,
                      title: 'Live Analytics Dashboard',
                      description:
                          'Track real-time platform usage, destination popularity trends, and live community stats.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
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
