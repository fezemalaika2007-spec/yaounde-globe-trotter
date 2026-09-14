import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// A modern, borderless, scroll-reveal animated hero footer.
///
/// Features:
/// - Borderless design with soft ambient glow & floating glass shadow
/// - Hero brand header with badge chip
/// - Sleek 4-column feature highlights bar
/// - Styled contact pods with hover animation
/// - Pulsing heart copyright signature
class AppFooter extends StatefulWidget {
  final void Function(int)? onNavigate;

  const AppFooter({super.key, this.onNavigate});

  @override
  State<AppFooter> createState() => _AppFooterState();
}

class _AppFooterState extends State<AppFooter>
    with SingleTickerProviderStateMixin {
  final GlobalKey _footerKey = GlobalKey();
  late final AnimationController _entranceController;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _entranceFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0.0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    final pos = scrollable?.position;
    if (pos != null && !_hasAnimated) {
      pos.addListener(_onScroll);
    }
    _checkVisibility();
  }

  @override
  void dispose() {
    try {
      final pos = Scrollable.maybeOf(context)?.position;
      if (pos != null) pos.removeListener(_onScroll);
    } catch (_) {}
    _entranceController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasAnimated) _checkVisibility();
  }

  void _checkVisibility() {
    if (_hasAnimated) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasAnimated || !mounted) return;
      final renderBox =
          _footerKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final position = renderBox.localToGlobal(Offset.zero);
      final viewportHeight = MediaQuery.of(context).size.height;

      if (position.dy < viewportHeight) {
        _hasAnimated = true;
        try {
          final pos = Scrollable.maybeOf(context)?.position;
          if (pos != null) pos.removeListener(_onScroll);
        } catch (_) {}
        _entranceController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _entranceFade,
          child: SlideTransition(position: _entranceSlide, child: child),
        );
      },
      child: _buildFooterContent(context, theme, l10n),
    );
  }

  Widget _buildFooterContent(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      key: _footerKey,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 48, 16, 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                  theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.95),
                ]
              : [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                  theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.9),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 36,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Brand & Tagline Header Row ---
                  Wrap(
                    spacing: 24,
                    runSpacing: 20,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.travel_explore_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Yaounde.Trip',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                ),
                                child: Text(
                                  'SMART TRAVEL PLATFORM',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.footerTagline,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // --- App Highlights Bar ---
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _HighlightBadge(
                        icon: Icons.place_rounded,
                        label: '150+ Verified Destinations',
                      ),
                      _HighlightBadge(
                        icon: Icons.psychology_rounded,
                        label: 'AI Recommendation Engine',
                      ),
                      _HighlightBadge(
                        icon: Icons.alt_route_rounded,
                        label: 'Smart Itinerary Builder',
                      ),
                      _HighlightBadge(
                        icon: Icons.forum_rounded,
                        label: 'Live Community Stream',
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // --- Contact Pods Row ---
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _ContactPod(
                        icon: Icons.email_outlined,
                        label: 'contact@yaounde.trip',
                      ),
                      _ContactPod(
                        icon: Icons.language_rounded,
                        label: 'www.yaounde.trip',
                      ),
                      _ContactPod(
                        icon: Icons.location_on_outlined,
                        label: l10n.footerAddress,
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // --- Bottom Row: Copyright & Signature ---
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.footerCopyright,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.footerMadeWith,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _PulsingHeart(),
                          const SizedBox(width: 6),
                          Text(
                            l10n.footerInCameroon,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A borderless highlight badge capsule.
class _HighlightBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HighlightBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// A borderless contact chip pod.
class _ContactPod extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ContactPod({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A subtle pulsing heart icon for the "Made with love" section.
class _PulsingHeart extends StatefulWidget {
  @override
  State<_PulsingHeart> createState() => _PulsingHeartState();
}

class _PulsingHeartState extends State<_PulsingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Transform.scale(scale: _pulseAnim.value, child: child);
      },
      child: Icon(Icons.favorite_rounded, size: 16, color: Colors.red.shade400),
    );
  }
}
