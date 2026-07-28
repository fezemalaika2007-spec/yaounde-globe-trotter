import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_provider.dart';
import '../services/theme_provider.dart';
import 'home_screen.dart';
import 'recommendations_screen.dart';
import 'itineraries_screen.dart';

/// Main app shell shown after login.
///
/// Uses a bottom navigation bar to switch between Destinations,
/// Recommendations, and Itineraries tabs.  An overflow menu provides
/// logout and settings.
class MainShell extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const MainShell({super.key, required this.onLocaleChanged});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _titles = ['Destinations', 'Recommendations', 'Itineraries'];

  @override
  void initState() {
    super.initState();
    AuthProvider().addListener(_onAuthChange);
  }

  @override
  void dispose() {
    AuthProvider().removeListener(_onAuthChange);
    super.dispose();
  }

  void _onAuthChange() {
    if (!mounted) return;
    if (!AuthProvider().isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _logout() async {
    await AuthProvider().logout();
    // _onAuthChange will trigger navigation to login
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeProvider();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                _logout();
              } else if (value == 'en') {
                await AppLocalizations.persistLocale(const Locale('en'));
                widget.onLocaleChanged(const Locale('en'));
              } else if (value == 'fr') {
                await AppLocalizations.persistLocale(const Locale('fr'));
                widget.onLocaleChanged(const Locale('fr'));
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
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onLocaleChanged: widget.onLocaleChanged),
          RecommendationsScreen(onLocaleChanged: widget.onLocaleChanged),
          ItinerariesScreen(onLocaleChanged: widget.onLocaleChanged),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: l10n.destinations,
          ),
          NavigationDestination(
            icon: const Icon(Icons.star_outline),
            selectedIcon: const Icon(Icons.star),
            label: l10n.recommendations,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: l10n.itineraries,
          ),
        ],
      ),
    );
  }
}
