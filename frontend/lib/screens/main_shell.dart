import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/theme_provider.dart';
import '../widgets/destination_card.dart';
import '../widgets/empty_state.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'recommendations_screen.dart';
import 'itineraries_screen.dart';
import 'favorites_screen.dart';

/// Main app shell shown after login.
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

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeProvider();

    final navItems = [
      _NavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l10n.home,
      ),
      _NavItem(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
        label: l10n.destinations,
      ),
      _NavItem(
        icon: Icons.star_outline,
        selectedIcon: Icons.star,
        label: l10n.recommendations,
      ),
      _NavItem(
        icon: Icons.favorite_border,
        selectedIcon: Icons.favorite,
        label: l10n.favorites,
      ),
      _NavItem(
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
        label: l10n.itineraries,
      ),
    ];

    final titles = navItems.map((n) => n.label).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Yaounde.Trip · ${titles[_currentIndex]}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'profile')
                _showProfileSheet();
              else if (value == 'logout')
                _logout();
              else if (value == 'en') {
                await AppLocalizations.persistLocale(const Locale('en'));
                widget.onLocaleChanged(const Locale('en'));
              } else if (value == 'fr') {
                await AppLocalizations.persistLocale(const Locale('fr'));
                widget.onLocaleChanged(const Locale('fr'));
              } else if (value == 'toggle_theme')
                await theme.toggleTheme();
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.travel_explore,
                    size: 40,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yaounde.Trip',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.exploreSubtitle,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ...List.generate(navItems.length, (i) {
              final item = navItems[i];
              return ListTile(
                leading: Icon(
                  _currentIndex == i ? item.selectedIcon : item.icon,
                  color: _currentIndex == i
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: _currentIndex == i
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _currentIndex == i
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                selected: _currentIndex == i,
                onTap: () => _navigateTo(i),
              );
            }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l10n.profile),
              onTap: () {
                Navigator.of(context).pop();
                _showProfileSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                l10n.logout,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
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

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Destinations tab — now dynamically loaded from backend (Overpass data).
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
  final _searchCtrl = TextEditingController();

  List<dynamic> _allDestinations = [];
  List<dynamic> _filteredDestinations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyLocalFilters);
    _fetch();
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    _costCtrl.dispose();
    _searchCtrl.dispose();
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
      final results = await _api.getDestinations(
        tag: _tagCtrl.text.trim().isEmpty ? null : _tagCtrl.text.trim(),
        maxCost: maxCost,
      );
      _allDestinations = results;
      _applyLocalFilters();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load destinations';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyLocalFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredDestinations = List.from(_allDestinations);
    } else {
      _filteredDestinations = _allDestinations.where((d) {
        final name = (d['name'] ?? '').toString().toLowerCase();
        final desc = (d['description'] ?? '').toString().toLowerCase();
        return name.contains(query) || desc.contains(query);
      }).toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: l10n.search,
              hintText: 'Search by name or description...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
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
              : _filteredDestinations.isEmpty
              ? EmptyState(
                  icon: Icons.explore_outlined,
                  title: l10n.noDestinations,
                  message: l10n.nothingHere,
                  onAction: _fetch,
                  actionLabel: l10n.refresh,
                )
              : ListView.builder(
                  itemCount: _filteredDestinations.length,
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  itemBuilder: (_, i) {
                    final d = _filteredDestinations[i];
                    final name = d['name'] ?? '';
                    final imageUrl = d['image'] ?? '';
                    final cost = d['cost'];
                    final avgRating = (d['average_rating'] ?? 0).toDouble();
                    return DestinationCard(
                      imagePath: imageUrl,
                      name: name,
                      country: d['area'] ?? 'Yaoundé',
                      city: null,
                      cost: cost,
                      tags: d['tags'] ?? [],
                      description: d['description'],
                      rating: avgRating,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
