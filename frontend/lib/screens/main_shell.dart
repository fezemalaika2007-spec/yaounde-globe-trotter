import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/theme_provider.dart';
import '../utils/destination_filters.dart';
import '../widgets/destination_grid.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_loading.dart';
import 'home_screen.dart';

import 'profile_screen.dart';
import 'recommendations_screen.dart';
import 'itineraries_screen.dart';
import 'favorites_screen.dart';

/// Breakpoint at which the sidebar switches from drawer to permanent.
const double _sidebarBreakpoint = 850;

/// Main app shell shown after login.
class MainShell extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const MainShell({super.key, required this.onLocaleChanged});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Lazily-created tab screens. Screens are only built the first time the
  // user visits them, so logging in only builds the Home tab instead of
  // firing network requests for ALL tabs at once (which froze the app).
  final List<Widget?> _screens = List<Widget?>.filled(5, null);

  /// Non-null children for [IndexedStack]; unbuilt tabs render as an empty
  /// box so index alignment is preserved.
  List<Widget> get _stackChildren =>
      _screens.map((w) => w ?? const SizedBox.shrink()).toList();

  @override
  void initState() {
    super.initState();
    // Pre-build only the initial (Home) tab.
    _getScreen(0);
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

  /// Builds (once) and caches the widget for [index].
  Widget _getScreen(int index) {
    final cached = _screens[index];
    if (cached != null) return cached;
    late final Widget built;
    switch (index) {
      case 0:
        built = HomeScreen(
          onLocaleChanged: widget.onLocaleChanged,
          onSwitchTab: _switchTo,
        );
        break;
      case 1:
        built = _DestinationsTab(onLocaleChanged: widget.onLocaleChanged);
        break;
      case 2:
        built = RecommendationsScreen(
          onLocaleChanged: widget.onLocaleChanged,
          onExplore: () => _switchTo(1),
        );
        break;
      case 3:
        built = FavoritesScreen(onLocaleChanged: widget.onLocaleChanged);
        break;
      case 4:
        built = ItinerariesScreen(onLocaleChanged: widget.onLocaleChanged);
        break;
      default:
        built = const SizedBox.shrink();
    }
    _screens[index] = built;
    return built;
  }

  /// Switches tabs and lazily builds the target screen on first visit.
  void _switchTo(int index) {
    if (index < 0 || index >= _screens.length) return;
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _getScreen(index);
    });
  }

  void _navigateTo(int index) => _switchTo(index);

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

  /// Builds the app bar actions menu (theme, language, profile, logout).
  List<Widget> _buildAppBarActions(AppLocalizations l10n, ThemeProvider theme) {
    return [
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
    ];
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _sidebarBreakpoint;

        if (isWide) {
          // --- Wide layout: permanent sidebar + content side by side ---
          return Scaffold(
            appBar: AppBar(
              title: Text('Yaounde.Trip · ${titles[_currentIndex]}'),
              actions: _buildAppBarActions(l10n, theme),
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Permanent sidebar
                _SidebarPanel(
                  navItems: navItems,
                  currentIndex: _currentIndex,
                  l10n: l10n,
                  onNavigate: _navigateTo,
                  onProfile: _showProfileSheet,
                  onLogout: _logout,
                ),
                // Vertical divider
                const VerticalDivider(width: 1, thickness: 1),
                // Main content area
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _stackChildren,
                  ),
                ),
              ],
            ),
          );
        } else {
          // --- Narrow layout: bottom navigation bar + drawer ---
          return Scaffold(
            appBar: AppBar(
              title: Text('Yaounde.Trip · ${titles[_currentIndex]}'),
              actions: _buildAppBarActions(l10n, theme),
            ),
            drawer: _buildDrawer(l10n, navItems),
            body: IndexedStack(index: _currentIndex, children: _stackChildren),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) => _switchTo(idx),
              destinations: navItems.map((item) {
                return NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                );
              }).toList(),
            ),
          );
        }

      },
    );
  }

  Widget _buildDrawer(AppLocalizations l10n, List<_NavItem> navItems) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
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
              onTap: () {
                setState(() => _currentIndex = i);
                Navigator.of(context).pop();
              },
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
            title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.of(context).pop();
              _logout();
            },
          ),
        ],
      ),
    );
  }
}

/// Reusable sidebar panel for the wide (permanent) layout.
class _SidebarPanel extends StatelessWidget {
  final List<_NavItem> navItems;
  final int currentIndex;
  final AppLocalizations l10n;
  final void Function(int) onNavigate;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  const _SidebarPanel({
    required this.navItems,
    required this.currentIndex,
    required this.l10n,
    required this.onNavigate,
    required this.onProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        children: [
          // Header — same gradient style as the drawer header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.travel_explore,
                  size: 36,
                  color: theme.colorScheme.onPrimary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Yaounde.Trip',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.exploreSubtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Navigation items
          ...List.generate(navItems.length, (i) {
            final item = navItems[i];
            final isSelected = currentIndex == i;
            return ListTile(
              leading: Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                item.label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              selected: isSelected,
              selectedTileColor: theme.colorScheme.primaryContainer.withValues(
                alpha: 0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () => onNavigate(i),
            );
          }),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.person_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              l10n.profile,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            onTap: onProfile,
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
            onTap: onLogout,
          ),
          const SizedBox(height: 8),
        ],
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

  String _selectedCategory = 'All';
  String _sortBy = 'Featured';

  List<dynamic> _allDestinations = [];
  List<dynamic> _filteredDestinations = [];
  List<dynamic> _liveResults = [];
  bool _loading = true;
  bool _liveSearching = false;
  String? _error;
  Timer? _searchDebounce;

  static const List<String> _categories = [
    'All',
    'Nature & Parks',
    'Culture & History',
    'Food & Dining',
    'Shopping',
    'Adventure',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _fetch();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tagCtrl.dispose();
    _costCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchCtrl.text.trim();
    _applyLocalFilters();
    if (query.length < 2) {
      if (_liveResults.isNotEmpty || _liveSearching) {
        setState(() {
          _liveResults = [];
          _liveSearching = false;
        });
      }
      return;
    }
    _liveSearching = true;
    setState(() {});
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _performLiveSearch(query);
    });
  }

  Future<void> _performLiveSearch(String query) async {
    try {
      final results = await _api.searchDestinations(query, limit: 12);
      final deduped = _deduplicateDestinations(results);
      if (mounted) {
        setState(() {
          _liveResults = deduped;
          _liveSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liveResults = [];
          _liveSearching = false;
        });
      }
    }
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
      _allDestinations = _deduplicateDestinations(results);
      _applyLocalFilters();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load destinations';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _deduplicateDestinations(List<dynamic> destinations) {
    return deduplicateDestinations(destinations);
  }

  void _applyLocalFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredDestinations = List.from(_allDestinations);
      setState(() {});
      return;
    }
    _searchLive(query);
  }

  Future<void> _searchLive(String query) async {
    try {
      final liveResults = await _api.searchDestinations(query, limit: 12);
      final merged = List<Map<String, dynamic>>.from(
        _allDestinations.cast<Map<String, dynamic>>(),
      );
      for (final live in liveResults) {
        if (live is! Map<String, dynamic>) continue;
        if (!isDestinationValid(live)) continue;
        final key = normalizeDestinationKey(live);
        if (key.isEmpty) continue;
        final alreadyExists = merged.any(
          (m) => normalizeDestinationKey(m) == key,
        );
        if (!alreadyExists) {
          merged.add(live);
        }
      }
      _filteredDestinations = merged.where((d) {
        final name = (d['name'] ?? '').toString().toLowerCase();
        final desc = (d['description'] ?? '').toString().toLowerCase();
        final area = (d['area'] ?? '').toString().toLowerCase();
        final tags = (d['tags'] ?? []).join(' ').toLowerCase();
        final searchable = '$name $desc $area $tags';
        return searchable.contains(query);
      }).toList();
      setState(() {});
    } catch (_) {
      _filteredDestinations = _allDestinations.where((d) {
        final name = (d['name'] ?? '').toString().toLowerCase();
        final desc = (d['description'] ?? '').toString().toLowerCase();
        return name.contains(query) || desc.contains(query);
      }).toList();
      setState(() {});
    }
  }

  List<dynamic> get _visibleDestinations {
    final source = _liveResults.isEmpty ? _filteredDestinations : () {
      final seenKeys = <String>{};
      final merged = <dynamic>[];
      for (final d in _filteredDestinations) {
        if (d is! Map<String, dynamic>) continue;
        final key = normalizeDestinationKey(d);
        if (key.isNotEmpty) seenKeys.add(key);
        merged.add(d);
      }
      for (final d in _liveResults) {
        if (d is! Map<String, dynamic>) continue;
        final key = normalizeDestinationKey(d);
        if (key.isNotEmpty && seenKeys.contains(key)) continue;
        if (key.isNotEmpty) seenKeys.add(key);
        merged.add(d);
      }
      return merged;
    }();

    // 1. Filter by category
    var result = source.where((d) {
      if (d is! Map<String, dynamic>) return false;
      if (_selectedCategory == 'All') return true;
      final category = (d['category'] ?? '').toString().toLowerCase();
      final tags = ((d['tags'] as List<dynamic>?) ?? []).map((t) => t.toString().toLowerCase()).toList();
      final catTarget = _selectedCategory.toLowerCase();
      return category.contains(catTarget) || tags.any((t) => catTarget.contains(t) || t.contains(catTarget));
    }).toList();

    // 2. Sort
    if (_sortBy == 'Rating') {
      result.sort((a, b) => ((b['average_rating'] ?? 0) as num).compareTo((a['average_rating'] ?? 0) as num));
    } else if (_sortBy == 'Price') {
      result.sort((a, b) => ((a['cost'] ?? 999999) as num).compareTo((b['cost'] ?? 999999) as num));
    } else if (_sortBy == 'Name') {
      result.sort((a, b) => (a['name'] ?? '').toString().compareTo(b['name'] ?? ''));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = _searchCtrl.text.trim();

    return Column(
      children: [
        // Search input
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: l10n.search,
              hintText: 'Search destinations in Yaoundé...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        _applyLocalFilters();
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: _categories.map((cat) {
              final selected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (val) {
                    setState(() => _selectedCategory = val ? cat : 'All');
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Sorting & Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              Text(
                'Sort by:',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sortBy,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'Featured', child: Text('Featured')),
                  DropdownMenuItem(value: 'Rating', child: Text('Highest Rated')),
                  DropdownMenuItem(value: 'Price', child: Text('Lowest Price')),
                  DropdownMenuItem(value: 'Name', child: Text('Name A-Z')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _sortBy = val);
                },
              ),
              const Spacer(),
              if (_selectedCategory != 'All' || query.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = 'All';
                      _sortBy = 'Featured';
                      _searchCtrl.clear();
                      _applyLocalFilters();
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off, size: 16),
                  label: const Text('Reset'),
                ),
            ],
          ),
        ),

        Expanded(
          child: _loading
              ? const ShimmerGrid(count: 6)
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _fetch, child: Text(l10n.tryAgain)),
                    ],
                  ),
                )
              : _visibleDestinations.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_liveSearching)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text('Searching online for “$query”...'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: EmptyState(
                        icon: Icons.explore_outlined,
                        title: l10n.noDestinations,
                        message: query.isEmpty
                            ? 'No places found in this category.'
                            : 'No places found locally. Keep typing to search online for real Yaoundé destinations.',
                        onAction: _fetch,
                        actionLabel: l10n.refresh,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    if (query.isNotEmpty && _liveSearching)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: DestinationGrid(
                        destinations: _visibleDestinations.cast<Map<String, dynamic>>(),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

