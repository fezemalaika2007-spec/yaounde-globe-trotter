import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
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
  List<String> _favoriteNames = [];
  List<dynamic> _allDestinations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getDestinations(),
        _api.getFavorites(),
      ]);
      _allDestinations = results[0];
      _favoriteNames = results[1].cast<String>();
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
    final theme = Theme.of(context);

    final favoriteDestinations = _allDestinations
        .where((d) => _favoriteNames.contains(d['name']))
        .toList();

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
              : favoriteDestinations.isEmpty
              ? EmptyState(
                  icon: Icons.favorite_border,
                  title: l10n.noFavorites,
                  message: l10n.noFavoritesMessage,
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
                      latitude: d['latitude'] != null ? (d['latitude'] as num).toDouble() : null,
                      longitude: d['longitude'] != null ? (d['longitude'] as num).toDouble() : null,
                      address: d['address'] ?? '',
                      category: d['category'] ?? '',
                      activities: d['activities'] ?? [],
                      openingHours: d['opening_hours'] ?? '',
                      phone: d['phone'] ?? '',
                      website: d['website'] ?? '',
                      email: d['email'] ?? '',
                      priceLevel: d['price_level'] != null ? d['price_level'] as int : null,
                      facilities: d['facilities'] ?? [],
                      cuisine: d['cuisine'] ?? '',
                      starRating: d['star_rating'] != null ? (d['star_rating'] as num).toDouble() : null,
                      images: d['images'] ?? [],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
