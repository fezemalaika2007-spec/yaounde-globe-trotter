import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class DestinationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> destination;
  const DestinationDetailScreen({super.key, required this.destination});

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  final _api = ApiService();
  late Map<String, dynamic> _dest;
  bool _submittingRating = false;
  int _userRating = 0;
  int _galleryPage = 0;
  final PageController _galleryController = PageController();

  @override
  void initState() {
    super.initState();
    _dest = Map<String, dynamic>.from(widget.destination);
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open link: $urlString')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
      }
    }
  }

  Future<void> _submitRating(int rating) async {
    setState(() {
      _submittingRating = true;
      _userRating = rating;
    });

    try {
      final response = await _api.submitRating(
        destinationId: _dest['id'] ?? '',
        rating: rating,
      );

      setState(() {
        _dest['average_rating'] = response['average_rating'];
        _dest['rating_count'] = response['rating_count'];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your rating has been recorded.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submittingRating = false);
      }
    }
  }

  Widget _buildGallery() {
    final List<dynamic> images = _dest['images'] ?? [];
    final String fallbackImage = _dest['image'] ?? '';
    final galleryImages = images.isNotEmpty
        ? images
        : (fallbackImage.isNotEmpty ? [fallbackImage] : []);

    if (galleryImages.isEmpty) {
      return Container(
        height: 250,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.place, size: 64),
      );
    }

    return SizedBox(
      height: 285,
      child: Stack(
        children: [
          PageView.builder(
            controller: _galleryController,
            itemCount: galleryImages.length,
            onPageChanged: (page) => setState(() => _galleryPage = page),
            itemBuilder: (context, index) {
              final imgUrl = galleryImages[index].toString();
              return Image.network(
                imgUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) => Container(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const Icon(Icons.broken_image, size: 48),
                ),
              );
            },
          ),
          if (galleryImages.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(galleryImages.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _galleryPage == index ? 12 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _galleryPage == index
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white70,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String act) {
    final a = act.toLowerCase();
    if (a.contains('hike') || a.contains('walk') || a.contains('trek')) {
      return Icons.terrain;
    }
    if (a.contains('dining') || a.contains('food') || a.contains('cuisine')) {
      return Icons.restaurant;
    }
    if (a.contains('accommodat') || a.contains('stay') || a.contains('hotel')) {
      return Icons.hotel;
    }
    if (a.contains('museum') || a.contains('cultur') || a.contains('history')) {
      return Icons.museum;
    }
    if (a.contains('shop') || a.contains('market') || a.contains('mall')) {
      return Icons.shopping_bag;
    }
    if (a.contains('sport') || a.contains('event') || a.contains('stadium')) {
      return Icons.sports_soccer;
    }
    if (a.contains('swim') || a.contains('pool') || a.contains('water')) {
      return Icons.pool;
    }
    if (a.contains('picnic')) {
      return Icons.local_play;
    }
    if (a.contains('photo') || a.contains('sightsee')) {
      return Icons.camera_alt;
    }
    return Icons.explore;
  }

  IconData _getFacilityIcon(String fac) {
    final f = fac.toLowerCase();
    if (f.contains('parking')) {
      return Icons.local_parking;
    }
    if (f.contains('wheelchair') || f.contains('access')) {
      return Icons.accessible;
    }
    if (f.contains('wifi') || f.contains('internet')) {
      return Icons.wifi;
    }
    if (f.contains('restroom') || f.contains('toilet') || f.contains('wc')) {
      return Icons.wc;
    }
    if (f.contains('child') || f.contains('play') || f.contains('kid')) {
      return Icons.child_care;
    }
    if (f.contains('air conditioning') || f.contains('ac')) {
      return Icons.ac_unit;
    }
    if (f.contains('pool') || f.contains('swim')) {
      return Icons.pool;
    }
    if (f.contains('gym') || f.contains('fit')) {
      return Icons.fitness_center;
    }
    if (f.contains('prayer') || f.contains('worship')) {
      return Icons.place;
    }
    if (f.contains('atm')) {
      return Icons.local_atm;
    }
    if (f.contains('charge') || f.contains('ev')) {
      return Icons.ev_station;
    }
    if (f.contains('pet') || f.contains('dog')) {
      return Icons.pets;
    }
    if (f.contains('secur') || f.contains('guard')) {
      return Icons.security;
    }
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String name = _dest['name'] ?? 'Destination';
    final String category = _dest['category'] ?? 'attraction';
    final String description = _dest['description'] ?? '';
    final String address = _dest['address'] ?? '';
    final double? lat = _dest['latitude'] != null
        ? (_dest['latitude'] as num).toDouble()
        : null;
    final double? lon = _dest['longitude'] != null
        ? (_dest['longitude'] as num).toDouble()
        : null;
    final String hours = _dest['opening_hours'] ?? '';
    final String phone = _dest['phone'] ?? '';
    final String website = _dest['website'] ?? '';
    final String email = _dest['email'] ?? '';
    final String cuisine = _dest['cuisine'] ?? '';
    final int? priceLevel = _dest['price_level'] != null
        ? _dest['price_level'] as int
        : null;
    final double? starRating = _dest['star_rating'] != null
        ? (_dest['star_rating'] as num).toDouble()
        : null;
    final double avgRating = _dest['average_rating'] != null
        ? (_dest['average_rating'] as num).toDouble()
        : 0.0;
    final int ratingCount = _dest['rating_count'] ?? 0;

    final List<dynamic> activities = _dest['activities'] ?? [];
    final List<dynamic> facilities = _dest['facilities'] ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 285,
            pinned: true,
            leading: IconButton.filledTonal(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(background: _buildGallery()),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Category Badge ---
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getActivityIcon(category),
                            size: 14,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- Place Name ---
                    Text(
                      name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // --- Address text ---
                    if (address.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
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

                    // --- Ratings & Submissions section ---
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Average Rating',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          avgRating.toStringAsFixed(1),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '($ratingCount votes)',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (starRating != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Official Star Rating',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: List.generate(5, (index) {
                                          return Icon(
                                            index < starRating.round()
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber,
                                            size: 18,
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text(
                              'How would you rate this place?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_submittingRating) ...[
                              const SizedBox(
                                height: 32,
                                width: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ] else ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (index) {
                                  final ratingValue = index + 1;
                                  return IconButton(
                                    icon: Icon(
                                      _userRating >= ratingValue
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 32,
                                    ),
                                    onPressed: () => _submitRating(ratingValue),
                                  );
                                }),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Navigation action card ---
                    if (lat != null && lon != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () {
                            final mapsUrl =
                                'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
                            _launchUrl(mapsUrl);
                          },
                          icon: const Icon(Icons.navigation),
                          label: const Text('View on Google Maps'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // --- About / Description ---
                    Text(
                      'About',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- GPS Coordinates section ---
                    if (lat != null && lon != null) ...[
                      Text(
                        'GPS Coordinates',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.gps_fixed,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SelectableText(
                                'Lat: ${lat.toStringAsFixed(6)} , Lon: ${lon.toStringAsFixed(6)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // --- Activities & Experiences ---
                    if (activities.isNotEmpty) ...[
                      Text(
                        'Activities & Experiences',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: activities.map((act) {
                          return Chip(
                            avatar: Icon(
                              _getActivityIcon(act.toString()),
                              size: 16,
                            ),
                            label: Text(
                              act.toString(),
                              style: theme.textTheme.bodySmall,
                            ),
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHigh,
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // --- Facilities & Amenities ---
                    if (facilities.isNotEmpty) ...[
                      Text(
                        'Facilities & Amenities',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: facilities.map((fac) {
                          return Chip(
                            avatar: Icon(
                              _getFacilityIcon(fac.toString()),
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            label: Text(
                              fac.toString(),
                              style: theme.textTheme.bodySmall,
                            ),
                            backgroundColor: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.3),
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // --- Specific Details card ---
                    if (hours.isNotEmpty ||
                        cuisine.isNotEmpty ||
                        priceLevel != null) ...[
                      Text(
                        'Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            if (hours.isNotEmpty)
                              ListTile(
                                leading: const Icon(Icons.access_time),
                                title: const Text('Opening Hours'),
                                subtitle: Text(hours),
                              ),
                            if (cuisine.isNotEmpty) ...[
                              if (hours.isNotEmpty) const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.restaurant_menu),
                                title: const Text('Cuisine'),
                                subtitle: Text(cuisine),
                              ),
                            ],
                            if (priceLevel != null) ...[
                              if (hours.isNotEmpty || cuisine.isNotEmpty)
                                const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.attach_money),
                                title: const Text('Price Level'),
                                subtitle: Text('\$' * priceLevel),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // --- Contact Details section ---
                    if (phone.isNotEmpty ||
                        website.isNotEmpty ||
                        email.isNotEmpty) ...[
                      Text(
                        'Contact Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          if (phone.isNotEmpty)
                            Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              child: ListTile(
                                leading: const Icon(Icons.phone),
                                title: Text(phone),
                                trailing: IconButton(
                                  icon: const Icon(Icons.call),
                                  onPressed: () => _launchUrl('tel:$phone'),
                                ),
                              ),
                            ),
                          if (email.isNotEmpty)
                            Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              child: ListTile(
                                leading: const Icon(Icons.email),
                                title: Text(email),
                                trailing: IconButton(
                                  icon: const Icon(Icons.mail),
                                  onPressed: () => _launchUrl('mailto:$email'),
                                ),
                              ),
                            ),
                          if (website.isNotEmpty)
                            Card(
                              elevation: 0,
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              child: ListTile(
                                leading: const Icon(Icons.web),
                                title: Text(
                                  website,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: () {
                                    final webUrl = website.startsWith('http')
                                        ? website
                                        : 'https://$website';
                                    _launchUrl(webUrl);
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
