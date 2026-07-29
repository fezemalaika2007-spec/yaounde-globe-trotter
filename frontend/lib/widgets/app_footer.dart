import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// A comprehensive footer for the home screen.
///
/// Includes app branding, quick navigation links, contact info,
/// social media icons, and copyright notice.
class AppFooter extends StatelessWidget {
  final void Function(int)? onNavigate;
  final VoidCallback? onLogout;

  const AppFooter({super.key, this.onNavigate, this.onLogout});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Top section: Brand + Links columns ---
            Wrap(
              spacing: 48,
              runSpacing: 32,
              children: [
                // Brand column
                _FooterColumn(
                  title: 'Yaounde.Trip',
                  children: [
                    Text(
                      l10n.footerTagline,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _SocialIcon(
                          icon: Icons.facebook,
                          url: 'https://facebook.com',
                          color: const Color(0xFF1877F2),
                        ),
                        const SizedBox(width: 12),
                        _SocialIcon(
                          icon: Icons.camera_alt,
                          url: 'https://instagram.com',
                          color: const Color(0xFFE4405F),
                        ),
                        const SizedBox(width: 12),
                        _SocialIcon(
                          icon: Icons.email,
                          url: 'mailto:contact@yaounde.trip',
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),

                // Quick links column
                _FooterColumn(
                  title: l10n.footerQuickLinks,
                  children: [
                    _FooterLink(
                      icon: Icons.home_outlined,
                      label: l10n.home,
                      onTap: () => onNavigate?.call(0),
                    ),
                    _FooterLink(
                      icon: Icons.explore_outlined,
                      label: l10n.destinations,
                      onTap: () => onNavigate?.call(1),
                    ),
                    _FooterLink(
                      icon: Icons.star_outline,
                      label: l10n.recommendations,
                      onTap: () => onNavigate?.call(2),
                    ),
                    _FooterLink(
                      icon: Icons.favorite_border,
                      label: l10n.favorites,
                      onTap: () => onNavigate?.call(3),
                    ),
                    _FooterLink(
                      icon: Icons.map_outlined,
                      label: l10n.itineraries,
                      onTap: () => onNavigate?.call(4),
                    ),
                  ],
                ),

                // Contact column
                _FooterColumn(
                  title: l10n.footerContact,
                  children: [
                    _FooterInfo(
                      icon: Icons.location_on_outlined,
                      text: l10n.footerAddress,
                    ),
                    const SizedBox(height: 8),
                    _FooterInfo(
                      icon: Icons.phone_outlined,
                      text: '+237 6XX XXX XXX',
                    ),
                    const SizedBox(height: 8),
                    _FooterInfo(
                      icon: Icons.email_outlined,
                      text: 'contact@yaounde.trip',
                    ),
                    const SizedBox(height: 8),
                    _FooterInfo(icon: Icons.language, text: 'www.yaounde.trip'),
                  ],
                ),

                // About column
                _FooterColumn(
                  title: l10n.footerAbout,
                  children: [
                    Text(
                      l10n.footerAboutText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // --- Divider ---
            Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              height: 1,
            ),

            const SizedBox(height: 24),

            // --- Bottom section: Copyright + Legal links ---
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 8,
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
                    _LegalLink(label: l10n.footerPrivacy, onTap: () {}),
                    const SizedBox(width: 16),
                    _LegalLink(label: l10n.footerTerms, onTap: () {}),
                    const SizedBox(width: 16),
                    _LegalLink(label: l10n.footerCookies, onTap: () {}),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --- Made with love ---
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.footerMadeWith,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.favorite, size: 14, color: Colors.red.shade400),
                  const SizedBox(width: 4),
                  Text(
                    l10n.footerInCameroon,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FooterColumn({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _FooterLink({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FooterInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;
  final String url;
  final Color color;

  const _SocialIcon({
    required this.icon,
    required this.url,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // In a real app, use url_launcher to open the URL
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening: $url'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _LegalLink({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
