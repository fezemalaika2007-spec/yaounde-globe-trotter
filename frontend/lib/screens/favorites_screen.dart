import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/favorites_provider.dart';
import '../widgets/destination_card.dart';
import '../widgets/empty_state.dart';

class FavoritesScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const FavoritesScreen({super.key, required this.onLocaleChanged});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _api = ApiService();
  final _favProvider = FavoritesProvider();
  List<String> _favoriteNames = [];
  List<dynamic> _allDestinations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _favProvider.addListener(_onFavChange);
    _favoriteNames = _favProvider.favorites;
    _fetch();
  }

  void _onFavChange() {
    if (!mounted) return;
    setState(() => _favoriteNames = _favProvider.favorites);
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getDestinations(),
        _favProvider.loadFavorites(propagateErrors: true),
      ]);
      _allDestinations = results[0] as List<dynamic>;
      _favoriteNames = _favProvider.favorites;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load favorites';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite(String destinationName) async {
    try {
      final updated = await _favProvider.toggleFavorite(destinationName);
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
    final theme = Theme.of(context);

    final favoriteDestinations = _allDestinations
        .where((d) => _favoriteNames.contains(d['name']))
        .toList();

    final hasError = _error != null;
    final favoriteMessage = _error ?? l10n.failedToLoad;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Text(
                l10n.favorites,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          favoriteMessage,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.tonal(
                          onPressed: _fetch,
                          child: Text(l10n.refresh),
                        ),
                      ],
                    ),
                  ),
                )
              : favoriteDestinations.isEmpty
              ? EmptyState(
                  icon: Icons.favorite_border,
                  title: l10n.noFavorites,
                  message: _favoriteNames.isEmpty
                      ? l10n.noFavoritesMessage
                      : l10n.noFavorites,
                  onAction: _fetch,
                  actionLabel: l10n.refresh,
                )
              : ListView.builder(
                  itemCount: favoriteDestinations.length,
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  itemBuilder: (_, i) {
                    final d = favoriteDestinations[i];
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
                      averageRating: avgRating,
                      ratingCount: d['rating_count'] ?? 0,
                      isFavorite: true,
                      onFavoriteToggle: () => _toggleFavorite(name),
                      id: d['id'] ?? '',
                      osmId: d['osm_id'] ?? '',
                      latitude: d['latitude'] != null
                          ? (d['latitude'] as num).toDouble()
                          : null,
                      longitude: d['longitude'] != null
                          ? (d['longitude'] as num).toDouble()
                          : null,
                      address: d['address'] ?? '',
                      category: d['category'] ?? '',
                      activities: d['activities'] ?? [],
                      openingHours: d['opening_hours'] ?? '',
                      phone: d['phone'] ?? '',
                      website: d['website'] ?? '',
                      email: d['email'] ?? '',
                      priceLevel: d['price_level'] != null
                          ? d['price_level'] as int
                          : null,
                      facilities: d['facilities'] ?? [],
                      cuisine: d['cuisine'] ?? '',
                      starRating: d['star_rating'] != null
                          ? (d['star_rating'] as num).toDouble()
                          : null,
                      images: d['images'] ?? [],
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _favProvider.removeListener(_onFavChange);
    super.dispose();
  }
}
