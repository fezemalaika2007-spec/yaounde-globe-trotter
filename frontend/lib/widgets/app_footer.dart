import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// A scroll-reveal animated footer for the home screen.
///
/// Features:
/// - Hidden until scrolled into view, then fades in + slides up (once per visit)
/// - Clean modern layout with app branding, quick links, and copyright
/// - Hover/tap scale animation on interactive elements
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
      duration: const Duration(milliseconds: 380),
    );
    _entranceFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0.0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to the enclosing Scrollable's position so we react
    // when the user scrolls the footer into view.
    final scrollable = Scrollable.maybeOf(context);
    final pos = scrollable?.position;
    if (pos != null && !_hasAnimated) {
      pos.addListener(_onScroll);
    }
    _checkVisibility();
  }

  @override
  void dispose() {
    // Safely remove the listener
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

      // Trigger when the top of the footer enters the viewport
      if (position.dy < viewportHeight) {
        _hasAnimated = true;
        // Remove the scroll listener — fire once per page visit
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
    return Container(
      key: _footerKey,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Brand row: app name + tagline + quick links ---
            Wrap(
              spacing: 48,
              runSpacing: 28,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                // App name / tagline column
                SizedBox(
                  width: 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yaounde.Trip',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.footerTagline,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick links column
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.footerQuickLinks,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _FooterLinkItem(
                        label: l10n.destinations,
                        onTap: () => widget.onNavigate?.call(1),
                      ),
                      const SizedBox(height: 6),
                      _FooterLinkItem(
                        label: l10n.recommendations,
                        onTap: () => widget.onNavigate?.call(2),
                      ),
                      const SizedBox(height: 6),
                      _FooterLinkItem(
                        label: l10n.itineraries,
                        onTap: () => widget.onNavigate?.call(4),
                      ),
                    ],
                  ),
                ),
                // Contact column
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.footerContact,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _FooterContactLine(
                        icon: Icons.email_outlined,
                        text: 'contact@yaounde.trip',
                      ),
                      const SizedBox(height: 6),
                      _FooterContactLine(
                        icon: Icons.language,
                        text: 'www.yaounde.trip',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              height: 1,
            ),
            const SizedBox(height: 20),
            // --- Bottom row: copyright + "made with love" ---
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 10,
              children: [
                Text(
                  l10n.footerCopyright,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.footerMadeWith,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _PulsingHeart(),
                    const SizedBox(width: 4),
                    Text(
                      l10n.footerInCameroon,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single footer quick-link item with hover/tap scale animation.
class _FooterLinkItem extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const _FooterLinkItem({required this.label, this.onTap});

  @override
  State<_FooterLinkItem> createState() => _FooterLinkItemState();
}

class _FooterLinkItemState extends State<_FooterLinkItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _hovered
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _hovered = true),
        onTapUp: (_) => setState(() => _hovered = false),
        onTapCancel: () => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _hovered
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
          transform: Matrix4.diagonal3Values(
            _hovered ? 1.04 : 1.0,
            _hovered ? 1.04 : 1.0,
            1.0,
          ),
          transformAlignment: Alignment.centerLeft,
          child: Text(
            widget.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: _hovered ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// A contact info line with an icon.
class _FooterContactLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FooterContactLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
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
      child: Icon(Icons.favorite, size: 14, color: Colors.red.shade400),
    );
  }
}
