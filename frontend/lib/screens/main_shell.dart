import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/theme_provider.dart';
import '../widgets/destination_grid.dart';
import '../widgets/empty_state.dart';
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
          // --- Narrow layout: drawer-based navigation (unchanged) ---
          return Scaffold(
            appBar: AppBar(
              title: Text('Yaounde.Trip · ${titles[_currentIndex]}'),
              actions: _buildAppBarActions(l10n, theme),
            ),
            drawer: _buildDrawer(l10n, navItems),
            body: IndexedStack(index: _currentIndex, children: _stackChildren),
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
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
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
    final seenKeys = <String>{};
    final unique = <dynamic>[];
    for (final destination in destinations) {
      if (destination is! Map<String, dynamic>) continue;
      if (!_isDestinationValid(destination)) continue;
      final key = _normalizeDestinationKey(destination);
      if (key.isEmpty || seenKeys.contains(key)) continue;
      seenKeys.add(key);
      unique.add(destination);
    }
    return unique;
  }

  bool _isDestinationValid(Map<String, dynamic> destination) {
    final name = (destination['name'] ?? '').toString().trim();
    if (name.isEmpty || !_hasGoodName(name)) return false;
    if (!_hasValidImage(destination)) return false;
    if (!_hasGoodLocation(destination)) return false;
    if (!_hasGoodDescription(destination)) return false;
    return true;
  }

  bool _hasGoodName(String name) {
    final normalized = name.toLowerCase();
    if (normalized.length < 4) return false;
    final badPatterns = [
      'unnamed',
      'no name',
      'road',
      'street',
      'path',
      'route',
      'way',
      'voie',
      'chemin',
      'ligne',
      'line',
      'unknown',
      'null',
      'drainage',
      'track',
      'roundabout',
      'bridge',
      'interchange',
      'poi',
      'point of interest',
    ];
    return !badPatterns.any(normalized.contains);
  }

  bool _hasValidImage(Map<String, dynamic> destination) {
    final image = (destination['image'] ?? '').toString().trim();
    if (image.isEmpty) return false;
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return true;
    }
    return false;
  }

  bool _hasGoodLocation(Map<String, dynamic> destination) {
    final area = (destination['area'] ?? '').toString().toLowerCase();
    final city = (destination['city'] ?? '').toString().toLowerCase();
    final tags = ((destination['tags'] as List<dynamic>?) ?? [])
        .map((tag) => tag.toString().toLowerCase())
        .toList();
    final name = (destination['name'] ?? '').toString().toLowerCase();

    if (area.contains('yaound') || city.contains('yaound')) return true;
    if (name.contains('yaound')) return true;
    if (tags.any((tag) => tag.contains('yaound') || tag.contains('cameroon'))) {
      return true;
    }
    return false;
  }

  bool _hasGoodDescription(Map<String, dynamic> destination) {
    final desc = (destination['description'] ?? '').toString().trim();
    if (desc.isEmpty) {
      final tags = (destination['tags'] as List<dynamic>?) ?? [];
      final category = (destination['category'] ?? '').toString().trim();
      return tags.length >= 2 || category.isNotEmpty;
    }
    if (desc.length < 30) return false;
    final badDescPatterns = [
      'no description',
      'n/a',
      'none',
      'unknown',
      'no details',
      'no info',
    ];
    return !badDescPatterns.any(desc.toLowerCase().contains);
  }

  String _normalizeDestinationKey(Map<String, dynamic> destination) {
    final id = destination['id']?.toString().trim();
    if (id?.isNotEmpty == true) return id!;
    final name = (destination['name'] ?? '').toString().trim();
    final image = (destination['image'] ?? '').toString().trim();
    if (name.isNotEmpty && image.isNotEmpty) {
      return '${_normalizeString(name)}|${image.toLowerCase()}';
    }
    if (name.isNotEmpty) {
      return _normalizeString(name);
    }
    return image;
  }

  String _normalizeString(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
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
              : DestinationGrid(
                  destinations: _filteredDestinations
                      .cast<Map<String, dynamic>>(),
                ),
        ),
      ],
    );
  }
}
