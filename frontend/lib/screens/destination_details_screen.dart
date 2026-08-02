import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/favorites_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _dest = Map<String, dynamic>.from(widget.destination);
    _isFav = _favProvider.isFavorite(_dest['name'] ?? '');
    _favProvider.addListener(_onFavChange);
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

  Widget _buildGallery() {
    final List<dynamic> images = _dest['images'] ?? [];
    final String fallbackImage = _dest['image'] ?? '';

    final seen = <String>{};
    final uniqueGalleryImages = <String>[];

    for (final image in images) {
      final imageUrl = image.toString().trim();
      if (imageUrl.isEmpty || seen.contains(imageUrl)) continue;
      seen.add(imageUrl);
      uniqueGalleryImages.add(imageUrl);
    }

    if (uniqueGalleryImages.isEmpty && fallbackImage.isNotEmpty) {
      final normalizedFallback = fallbackImage.trim();
      if (normalizedFallback.isNotEmpty) {
        uniqueGalleryImages.add(normalizedFallback);
      }
    }

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
              return Image.network(
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
                      ).colorScheme.onBackground.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            );
          }),
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

  String _buildImageCaption(int index, int total) {
    final String name = _dest['name'] ?? 'Destination';
    final String category = (_dest['category'] ?? '').toString();
    final String desc =
        (_dest['long_description'] ?? _dest['description'] ?? '').toString();
    final snippet = desc.isNotEmpty
        ? (desc.length > 140 ? '${desc.substring(0, 140).trim()}...' : desc)
        : '';
    final imagePart = 'Image ${index + 1} of $total';
    final parts = <String>[];
    parts.add('$name${category.isNotEmpty ? ' — $category' : ''}');
    if (snippet.isNotEmpty) parts.add(snippet);
    parts.add(imagePart);
    return parts.join(' — ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String name = _dest['name'] ?? 'Destination';
    final String description =
        _dest['long_description'] ?? _dest['description'] ?? '';
    final String address = _dest['address'] ?? '';
    final double? lat = _dest['latitude'] != null
        ? (_dest['latitude'] as num).toDouble()
        : null;
    final double? lon = _dest['longitude'] != null
        ? (_dest['longitude'] as num).toDouble()
        : null;

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
            Text(
              'About',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
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
}
