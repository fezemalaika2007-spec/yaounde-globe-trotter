import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/theme_provider.dart';
import '../utils/image_paths.dart';
import '../widgets/destination_card.dart';
import '../widgets/empty_state.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'recommendations_screen.dart';
import 'itineraries_screen.dart';
import 'favorites_screen.dart';

/// Main app shell shown after login.
///
/// Uses a bottom navigation bar with 5 tabs: Home, Destinations,
/// Recommendations, Favorites, and Itineraries. An overflow menu provides
/// logout and settings.
class MainShell extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const MainShell({super.key, required this.onLocaleChanged});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        onLocaleChanged: widget.onLocaleChanged,
        onSwitchTab: (i) => setState(() => _currentIndex = i),
      ),
      _DestinationsTab(onLocaleChanged: widget.onLocaleChanged),
      RecommendationsScreen(onLocaleChanged: widget.onLocaleChanged),
      FavoritesScreen(onLocaleChanged: widget.onLocaleChanged),
      ItinerariesScreen(onLocaleChanged: widget.onLocaleChanged),
    ];
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeProvider();

    final titles = [
      l10n.home,
      l10n.destinations,
      l10n.recommendations,
      l10n.favorites,
      l10n.itineraries,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Yaounde.Trip · ${titles[_currentIndex]}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'profile') {
                _showProfileSheet();
              } else if (value == 'logout') {
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
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.profile),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.logout),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.home,
          ),
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
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
            label: l10n.favorites,
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

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: ProfileScreen(onLocaleChanged: widget.onLocaleChanged),
        ),
      ),
    );
  }
}

/// A destinations-only tab extracted from the former HomeScreen.
class _DestinationsTab extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const _DestinationsTab({required this.onLocaleChanged});

  @override
  State<_DestinationsTab> createState() => _DestinationsTabState();
}

class _DestinationsTabState extends State<_DestinationsTab> {
  final _api = ApiService();
  final _tagCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  List<dynamic> _destinations = [];
  List<String> _favoriteNames = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      int? maxCost;
      if (_costCtrl.text.trim().isNotEmpty) {
        maxCost = int.tryParse(_costCtrl.text.trim());
      }

      final results = await Future.wait([
        _api.getDestinations(
          tag: _tagCtrl.text.trim().isEmpty ? null : _tagCtrl.text.trim(),
          maxCost: maxCost,
        ),
        _api.getFavorites(),
      ]);
      _destinations = results[0];
      _favoriteNames = results[1].cast<String>();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load destinations';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite(String destinationName) async {
    try {
      final updated = await _api.toggleFavorite(destinationName);
      setState(() => _favoriteNames = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update favorites')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.tagFilter,
                    hintText: 'e.g. nature',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.maxCost,
                    hintText: 'e.g. 150',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.search),
                onPressed: _fetch,
                tooltip: l10n.search,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _fetch, child: Text(l10n.tryAgain)),
                    ],
                  ),
                )
              : _destinations.isEmpty
              ? EmptyState(
                  icon: Icons.explore_outlined,
                  title: l10n.noDestinations,
                  message: l10n.nothingHere,
                  onAction: _fetch,
                  actionLabel: l10n.refresh,
                )
              : ListView.builder(
                  itemCount: _destinations.length,
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  itemBuilder: (_, i) {
                    final d = _destinations[i];
                    final imageIndex = d['image_index'] ?? i;
                    final name = d['name'] ?? '';
                    return DestinationCard(
                      imagePath: ImagePaths.destination(imageIndex),
                      name: name,
                      country: d['country'] ?? '',
                      city: d['city'],
                      cost: d['avg_cost_per_day'],
                      tags: d['tags'] ?? [],
                      description: d['description'],
                      rating: (d['rating'] ?? 0).toDouble(),
                      bestTimeToVisit: d['best_time_to_visit'],
                      duration: d['duration'],
                      location: d['location'],
                      highlights: d['highlights'],
                      currency: d['currency'],
                      isFavorite: _favoriteNames.contains(name),
                      onFavoriteToggle: () => _toggleFavorite(name),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
