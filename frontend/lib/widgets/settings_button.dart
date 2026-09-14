import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/theme_provider.dart';

class SettingsButton extends StatelessWidget {
  final void Function(Locale) onLocaleChanged;

  const SettingsButton({super.key, required this.onLocaleChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeProvider();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings_outlined),
      onSelected: (value) async {
        if (value == 'en') {
          await AppLocalizations.persistLocale(const Locale('en'));
          onLocaleChanged(const Locale('en'));
        } else if (value == 'fr') {
          await AppLocalizations.persistLocale(const Locale('fr'));
          onLocaleChanged(const Locale('fr'));
        } else if (value == 'toggle_theme') {
          await theme.toggleTheme();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'toggle_theme',
          child: Row(
            children: [
              Icon(theme.isDarkMode ? Icons.light_mode : Icons.dark_mode),
              const SizedBox(width: 8),
              Text(theme.isDarkMode ? l10n.lightMode : l10n.darkMode),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'en',
          child: Row(
            children: [
              const Icon(Icons.language),
              const SizedBox(width: 8),
              Text(l10n.english),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'fr',
          child: Row(
            children: [
              const Icon(Icons.language),
              const SizedBox(width: 8),
              Text(l10n.french),
            ],
          ),
        ),
      ],
    );
  }
}
