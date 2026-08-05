import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/favorites_provider.dart';
import '../utils/destination_filters.dart';

class DestinationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> destination;
  const DestinationDetailScreen({super.key, required this.destination});

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  late Map<String, dynamic> _dest;
  final _favProvider = FavoritesProvider();
  bool _isFav = false;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  /// Fetched Wikipedia extract (real content), if the destination has a
  /// Wikipedia title we can resolve. Null until fetched.
  String? _wikiExtract;
  bool _wikiLoading = false;

  @override
  void initState() {
    super.initState();
    _dest = Map<String, dynamic>.from(widget.destination);
    _isFav = _favProvider.isFavorite(_dest['name'] ?? '');
    _favProvider.addListener(_onFavChange);
    _maybeFetchWikiExtract();
  }

  void _onFavChange() {
    if (!mounted) return;
    setState(() => _isFav = _favProvider.isFavorite(_dest['name'] ?? ''));
  }

  @override
  void dispose() {
    _favProvider.removeListener(_onFavChange);
    _pageController.dispose();
    super.dispose();
  }

  /// Fetches a real Wikipedia extract/summary for the destination when we have
  /// a Wikipedia/Wikidata reference or a name that can resolve via Wikipedia.
  ///
  /// This gives genuinely long, real content about the place. If the fetch
  /// fails or no Wikipedia article exists, we fall back to the generated
  /// long description (derived from real OSM tags) — never an invented text.
  Future<void> _maybeFetchWikiExtract() async {
    // Don't try if we already have a long real description from a previous
    // Wikipedia enrichment on the backend, unless the description is thin.
    final existing = _dest['long_description'] ?? _dest['description'] ?? '';
    if (existing.toString().trim().length >= 300) return;

    final wikipedia = _dest['wikipedia'] ?? '';
    final name = (_dest['name'] ?? '').toString().trim();
    if (wikipedia.toString().isNotEmpty || name.isEmpty) {
      if (wikipedia.toString().isNotEmpty) {
        await _fetchWikiExtractByName(wikipedia.toString());
      }
      return;
    }

    // Try a Wikipedia lookup by the destination's real name.
    await _fetchWikiExtractByName(name);
  }

  Future<void> _fetchWikiExtractByName(String query) async {
    setState(() => _wikiLoading = true);
    try {
      // Wikipedia REST summary API (no key required).
      final lang = 'en';
      final encoded = Uri.encodeComponent(query.replaceAll(' ', '_'));
      final uri = Uri.parse(
        'https://$lang.wikipedia.org/api/rest_v1/page/summary/$encoded',
      );
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () => throw Exception('Wikipedia request timed out'),
          );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final extract = data['extract'] ?? '';
        if (extract.toString().trim().isNotEmpty) {
          setState(() {
            _wikiExtract = extract.toString();
            // Keep a real content_description if provided by the API.
            final contentDesc = data['content_urls']?['desktop_page']?['title'];
            if (contentDesc != null) {
              _dest['wikipedia_title'] = contentDesc.toString();
            }
          });
        }
      }
    } catch (_) {
      // Silently fall back to the generated long description.
    } finally {
      if (mounted) setState(() => _wikiLoading = false);
    }
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      final bool canLaunch = await canLaunchUrl(url);
      if (!mounted) return;
      if (canLaunch) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $urlString')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
    }
  }

  /// Opens the full-screen, uncropped view of the image at [index].
  void _openFullImage(List<String> images, int index) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                // BoxFit.contain ensures the WHOLE image is visible, unlike
                // the BoxFit.cover used in card/gallery thumbnails.
                child: Image.network(
                  images[index],
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image, size: 64),
                    );
                  },
                ),
              ),
              Positioned(
                top: 32,
                right: 12,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: SafeArea(
                  child: Text(
                    _buildImageCaption(index, images.length),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, height: 1.3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGallery() {
    final List<dynamic> images = _dest['images'] ?? [];
    final String fallbackImage = _dest['image'] ?? '';

    // Normalized dedup: strips query strings/fragments and lowercases
    // scheme/netloc so the same photo served with different URL params
    // never appears more than once.
    final uniqueGalleryImages = uniqueImages(images, fallback: fallbackImage);

    if (uniqueGalleryImages.isEmpty) {
      return Container(
        height: 220,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.place, size: 64),
      );
    }

    final captionsCount = uniqueGalleryImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            itemCount: uniqueGalleryImages.length,
            onPageChanged: (idx) {
              if (!mounted) return;
              setState(() => _currentImageIndex = idx);
            },
            itemBuilder: (context, index) {
              final url = uniqueGalleryImages[index];
              final caption = _buildImageCaption(
                index,
                uniqueGalleryImages.length,
              );
              return GestureDetector(
                onTap: () => _openFullImage(uniqueGalleryImages, index),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  semanticLabel: caption,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: const Icon(Icons.broken_image, size: 48),
                    );
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(captionsCount, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentImageIndex == i ? 10 : 6,
              height: _currentImageIndex == i ? 10 : 6,
              decoration: BoxDecoration(
                color: _currentImageIndex == i
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        // "Tap to expand" hint — makes the feature discoverable.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.tap_and_play,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Tap any photo to view it full-screen',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _buildImageCaption(_currentImageIndex, captionsCount),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3),
          ),
        ),
      ],
    );
  }

  /// Builds a caption that leads with the destination's REAL name (from OSM
  /// / verified Wikidata), never a generic label. The index is only an
  /// auxiliary "image N of M" suffix, not the primary descriptor.
  String _buildImageCaption(int index, int total) {
    final String name = _dest['name'] ?? 'Destination';
    final String category = (_dest['category'] ?? '').toString();
    final parts = <String>[];
    parts.add('$name${category.isNotEmpty ? ' — $category' : ''}');
    if (total > 1) parts.add('Image ${index + 1} of $total');
    return parts.join(' — ');
  }

  /// Returns the real, full description of the destination.
  ///
  /// Priority:
  ///   1. Long description already enriched from Wikipedia (real content).
  ///   2. Wikipedia extract fetched live (real content).
  ///   3. Generated long description (built from real OSM tags).
  ///   4. Short description (real OSM description if any).
  ///   5. Empty — caller decides what to show.
  String _realDescription() {
    final longDesc = (_dest['long_description'] ?? '').toString().trim();
    if (longDesc.isNotEmpty) return longDesc;
    final wiki = (_wikiExtract ?? '').toString().trim();
    if (wiki.isNotEmpty) return wiki;
    final desc = (_dest['description'] ?? '').toString().trim();
    return desc;
  }

  String _formatCost(dynamic cost) {
    if (cost == null) return '';
    final num? c = cost is num ? cost : double.tryParse(cost.toString());
    if (c == null) return '';
    return '${c.toStringAsFixed(0)} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String name = _dest['name'] ?? 'Destination';
    final String description = _realDescription();
    final String address = _dest['address'] ?? '';
    final double? lat = _dest['latitude'] != null
        ? (_dest['latitude'] as num).toDouble()
        : null;
    final double? lon = _dest['longitude'] != null
        ? (_dest['longitude'] as num).toDouble()
        : null;
    final bool hasCost = _dest['cost'] != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: Icon(
              _isFav ? Icons.favorite : Icons.favorite_border,
              color: _isFav ? Colors.red : null,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _favProvider.toggleFavorite(_dest['name'] ?? '');
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      _isFav ? 'Removed from favorites' : 'Added to favorites',
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed updating favorite: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGallery(),
            const SizedBox(height: 12),
            Text(
              name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (address.isNotEmpty)
              Text(
                address,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),

            // --- Price section: real data only. Never invent a price. ---
            Text(
              'Price',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            if (hasCost)
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCost(_dest['cost']),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else
              Text(
                'Price information not available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),

            // --- About / real description ---
            Text(
              'About',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_wikiLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            Text(
              description.isEmpty
                  ? 'Detailed information about this place is not available yet.'
                  : description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),

            // --- Practical info (real OSM data, shown only when present) ---
            if ((_dest['opening_hours'] ?? '').toString().isNotEmpty) ...[
              _infoRow(
                Icons.schedule,
                'Hours',
                (_dest['opening_hours'] ?? '').toString(),
              ),
              const SizedBox(height: 6),
            ],
            if ((_dest['phone'] ?? '').toString().isNotEmpty) ...[
              _infoRow(Icons.phone, 'Phone', (_dest['phone'] ?? '').toString()),
              const SizedBox(height: 6),
            ],
            if ((_dest['website'] ?? '').toString().isNotEmpty) ...[
              _infoRow(
                Icons.language,
                'Website',
                (_dest['website'] ?? '').toString(),
              ),
              const SizedBox(height: 6),
            ],
            if ((_dest['cuisine'] ?? '').toString().isNotEmpty) ...[
              _infoRow(
                Icons.restaurant,
                'Cuisine',
                (_dest['cuisine'] ?? '').toString(),
              ),
              const SizedBox(height: 6),
            ],
            if ((_dest['activities'] as List<dynamic>? ?? []).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Things to do',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: (_dest['activities'] as List<dynamic>? ?? [])
                    .take(8)
                    .map(
                      (a) => Chip(
                        label: Text(
                          a.toString(),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            if (lat != null && lon != null)
              FilledButton.icon(
                onPressed: () => _launchUrl(
                  'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
                ),
                icon: const Icon(Icons.navigation),
                label: const Text('View on Google Maps'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
