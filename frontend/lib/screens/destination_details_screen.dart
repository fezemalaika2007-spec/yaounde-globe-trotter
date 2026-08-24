import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/favorites_provider.dart';
import '../services/api_service.dart';
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

  /// Opens the full-screen, uncropped view of the image at [index].
  void _openFullImage(List<String> images, int index) {
    final imagePath = images[index];
    final isNetwork = imagePath.startsWith('http://') || imagePath.startsWith('https://');
    final localFallback = getLocalAssetFallback(_dest['name'] ?? '');

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                // BoxFit.contain ensures the WHOLE image is visible
                child: isNetwork
                    ? Image.network(
                        imagePath,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          if (localFallback.isNotEmpty) {
                            return Image.asset(
                              localFallback,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (c, e, s) => const Center(
                                child: Icon(Icons.broken_image, size: 64, color: Colors.white70),
                              ),
                            );
                          }
                          return const Center(
                            child: Icon(Icons.broken_image, size: 64, color: Colors.white70),
                          );
                        },
                      )
                    : Image.asset(
                        imagePath.startsWith('assets/')
                            ? imagePath
                            : 'assets/images/$imagePath',
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.broken_image, size: 64, color: Colors.white70),
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
    final String destName = (_dest['name'] ?? '').toString();

    // Normalized dedup: strips query strings/fragments and lowercases
    // scheme/netloc so the same photo served with different URL params
    // never appears more than once.
    final uniqueGalleryImages = uniqueImages(
      images,
      fallback: fallbackImage,
      name: destName,
    );

    if (uniqueGalleryImages.isEmpty) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.primaryContainer.withValues(
                alpha: 0.5,
              ),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.place,
                size: 64,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(height: 8),
              Text(
                'No photos available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final captionsCount = uniqueGalleryImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 260,
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
              final isNet = url.startsWith('http://') || url.startsWith('https://');
              final localFallback = getLocalAssetFallback(destName);

              return GestureDetector(
                onTap: () => _openFullImage(uniqueGalleryImages, index),
                child: isNet
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        semanticLabel: caption,
                        errorBuilder: (context, error, stackTrace) {
                          if (localFallback.isNotEmpty) {
                            return Image.asset(
                              localFallback,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              semanticLabel: caption,
                              errorBuilder: (c, e, s) => Container(
                                color: Theme.of(context).colorScheme.secondaryContainer,
                                child: const Icon(Icons.broken_image, size: 48),
                              ),
                            );
                          }
                          return Container(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            child: const Icon(Icons.broken_image, size: 48),
                          );
                        },
                      )
                    : Image.asset(
                        url.startsWith('assets/') ? url : 'assets/images/$url',
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
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentImageIndex == i ? 24 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentImageIndex == i
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
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

  /// Builds a caption that leads with the destination's REAL name (from the
  /// Foursquare venue data), never a generic label. The index is only an
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
  ///   1. Long description generated on the backend from real Foursquare data.
  ///   2. Short description (real Foursquare description if any).
  ///   3. Empty — caller decides what to show.
  String _realDescription() {
    final longDesc = (_dest['long_description'] ?? '').toString().trim();
    if (longDesc.isNotEmpty) return longDesc;
    final desc = (_dest['description'] ?? '').toString().trim();
    return desc;
  }

  String _formatCost(dynamic cost) {
    if (cost == null) return '';
    final num? c = cost is num ? cost : double.tryParse(cost.toString());
    if (c == null) return '';
    return '${c.toStringAsFixed(0)} FCFA';
  }

  /// Opens the "Add to Itinerary" dialog, where the user can select an
  /// existing itinerary or create a new one with this destination pre-added.
  void _showAddToItineraryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddToItineraryDialog(
        destinationName: _dest['name'] ?? '',
      ),
    );
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
    final double avgRating = (_dest['average_rating'] ?? 0).toDouble();
    final int ratingCount = (_dest['rating_count'] ?? 0).toInt();

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
      // Floating "Add to Itinerary" button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddToItineraryDialog,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add to Itinerary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80), // room for FAB
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGallery(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Name & rating row ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (avgRating > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                avgRating.toStringAsFixed(1),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              if (ratingCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '($ratingCount)',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (address.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // --- Quick stats row ---
                  _buildQuickStats(theme, hasCost),
                  const SizedBox(height: 16),

                  // --- About / real description ---
                  _buildSectionHeader(theme, Icons.info_outline, 'About'),
                  const SizedBox(height: 8),
                  Text(
                    description.isEmpty
                        ? 'Detailed information about this place is not available yet.'
                        : description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: 16),

                  // --- Practical info (real venue data, shown only when present) ---
                  if (_hasPracticalInfo()) ...[
                    _buildSectionHeader(
                      theme,
                      Icons.article_outlined,
                      'Practical Info',
                    ),
                    const SizedBox(height: 8),
                    _buildPracticalInfoCard(theme),
                    const SizedBox(height: 16),
                  ],

                  // --- Activities ---
                  if ((_dest['activities'] as List<dynamic>? ?? [])
                      .isNotEmpty) ...[
                    _buildSectionHeader(
                      theme,
                      Icons.local_activity,
                      'Things to Do',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: (_dest['activities'] as List<dynamic>? ?? [])
                          .take(8)
                          .map(
                            (a) => Chip(
                              avatar: const Icon(Icons.check_circle, size: 16),
                              label: Text(
                                a.toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // --- Map preview card ---
                  if (lat != null && lon != null) ...[
                    _buildSectionHeader(
                      theme,
                      Icons.map,
                      'Location',
                    ),
                    const SizedBox(height: 8),
                    _buildMapPreviewCard(theme, lat, lon, name),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(ThemeData theme, bool hasCost) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _quickStatItem(
              theme,
              Icons.attach_money,
              hasCost ? _formatCost(_dest['cost']) : 'Free / N/A',
              'Price',
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _quickStatItem(
              theme,
              Icons.category,
              (_dest['category'] ?? 'General').toString(),
              'Category',
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _quickStatItem(
              theme,
              Icons.star,
              (_dest['average_rating'] ?? 0).toDouble() > 0
                  ? '${(_dest['average_rating'] ?? 0).toDouble().toStringAsFixed(1)}/5'
                  : 'Not rated',
              'Rating',
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStatItem(
    ThemeData theme,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  bool _hasPracticalInfo() {
    return (_dest['opening_hours'] ?? '').toString().isNotEmpty ||
        (_dest['phone'] ?? '').toString().isNotEmpty ||
        (_dest['website'] ?? '').toString().isNotEmpty ||
        (_dest['cuisine'] ?? '').toString().isNotEmpty;
  }

  Widget _buildPracticalInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          if ((_dest['opening_hours'] ?? '').toString().isNotEmpty)
            _infoRow(
              Icons.schedule,
              'Hours',
              (_dest['opening_hours'] ?? '').toString(),
            ),
          if ((_dest['phone'] ?? '').toString().isNotEmpty) ...[
            const Divider(height: 16),
            _infoRow(Icons.phone, 'Phone', (_dest['phone'] ?? '').toString()),
          ],
          if ((_dest['website'] ?? '').toString().isNotEmpty) ...[
            const Divider(height: 16),
            _infoRow(
              Icons.language,
              'Website',
              (_dest['website'] ?? '').toString(),
            ),
          ],
          if ((_dest['cuisine'] ?? '').toString().isNotEmpty) ...[
            const Divider(height: 16),
            _infoRow(
              Icons.restaurant,
              'Cuisine',
              (_dest['cuisine'] ?? '').toString(),
            ),
          ],
        ],
      ),
    );
  }

  /// Interactive map preview card with a static map image and a button to
  /// launch Google Maps navigation.
  Widget _buildMapPreviewCard(
    ThemeData theme,
    double lat,
    double lon,
    String name,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _launchUrl(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Static map image preview using OpenStreetMap tiles
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.secondaryContainer,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Map placeholder with coordinates
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map,
                          size: 48,
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${lat.toStringAsFixed(4)}°N, ${lon.toStringAsFixed(4)}°E',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Pin icon overlay
                  Center(
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Icon(
                        Icons.location_on,
                        size: 40,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Action bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.navigation,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'View on Google Maps',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          'Get directions to $name',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
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

// ---------------------------------------------------------------------------
// Add to Itinerary Dialog
// ---------------------------------------------------------------------------

class _AddToItineraryDialog extends StatefulWidget {
  final String destinationName;
  const _AddToItineraryDialog({required this.destinationName});

  @override
  State<_AddToItineraryDialog> createState() => _AddToItineraryDialogState();
}

class _AddToItineraryDialogState extends State<_AddToItineraryDialog> {
  final _api = ApiService();
  bool _loadingItineraries = true;
  bool _submitting = false;
  String? _error;
  List<dynamic> _itineraries = [];

  // New itinerary form
  bool _createNew = false;
  final _titleCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItineraries();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItineraries() async {
    try {
      final data = await _api.getItineraries();
      if (mounted) {
        setState(() {
          _itineraries = data;
          _loadingItineraries = false;
          // If no itineraries exist, default to create-new mode.
          if (_itineraries.isEmpty) _createNew = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingItineraries = false;
          _createNew = true;
        });
      }
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      ctrl.text =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// Adds the destination to an existing itinerary via PUT.
  Future<void> _addToExisting(Map<String, dynamic> itinerary) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final existingDests =
          List<String>.from(itinerary['destinations'] as List? ?? []);
      if (!existingDests.contains(widget.destinationName)) {
        existingDests.add(widget.destinationName);
      }
      await _api.updateItinerary(
        id: itinerary['id'].toString(),
        title: itinerary['title'] ?? '',
        destinations: existingDests,
        startDate: itinerary['start_date'] ?? '',
        endDate: itinerary['end_date'] ?? '',
        notes: itinerary['notes'] ?? '',
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.destinationName} added to "${itinerary['title']}"',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to update itinerary');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Creates a brand new itinerary with this destination.
  Future<void> _createNewItinerary() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _startCtrl.text.trim().isEmpty ||
        _endCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _api.createItinerary(
        title: _titleCtrl.text.trim(),
        destinations: [widget.destinationName],
        startDate: _startCtrl.text.trim(),
        endDate: _endCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Itinerary "${_titleCtrl.text.trim()}" created with ${widget.destinationName}',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to create itinerary');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_location_alt, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Add to Itinerary')),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Destination badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.place,
                      size: 16,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.destinationName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_loadingItineraries)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // Toggle between existing itineraries and creating new
                if (_itineraries.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Existing'),
                          selected: !_createNew,
                          onSelected: (v) =>
                              setState(() => _createNew = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Create New'),
                          selected: _createNew,
                          onSelected: (v) =>
                              setState(() => _createNew = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                if (!_createNew && _itineraries.isNotEmpty)
                  ...List.generate(_itineraries.length, (i) {
                    final it = _itineraries[i];
                    final dests = (it['destinations'] as List? ?? []);
                    final alreadyAdded =
                        dests.contains(widget.destinationName);
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          alreadyAdded ? Icons.check_circle : Icons.map,
                          color: alreadyAdded
                              ? Colors.green
                              : theme.colorScheme.primary,
                        ),
                        title: Text(
                          it['title'] ?? 'Untitled',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${it['start_date']} → ${it['end_date']} · ${dests.length} stops',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: alreadyAdded
                            ? const Text(
                                'Added',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                        enabled: !alreadyAdded && !_submitting,
                        onTap:
                            alreadyAdded ? null : () => _addToExisting(it),
                      ),
                    );
                  }),

                if (_createNew) ...[
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Itinerary Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _startCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Start Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.date_range),
                        onPressed: () => _pickDate(_startCtrl),
                      ),
                    ),
                    onTap: () => _pickDate(_startCtrl),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _endCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'End Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.date_range),
                        onPressed: () => _pickDate(_endCtrl),
                      ),
                    ),
                    onTap: () => _pickDate(_endCtrl),
                  ),
                ],
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_createNew)
          FilledButton(
            onPressed: _submitting ? null : _createNewItinerary,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create & Add'),
          ),
      ],
    );
  }
}
