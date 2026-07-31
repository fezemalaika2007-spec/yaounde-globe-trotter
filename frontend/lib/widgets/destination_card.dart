import 'package:flutter/material.dart';
import '../screens/destination_details_screen.dart';

class DestinationCard extends StatefulWidget {
  final String imagePath;
  final String name;
  final String country;
  final int? cost;
  final List<dynamic> tags;
  final String? description;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onViewDetails;
  final VoidCallback? onTap;
  final String? city;
  final double? rating;
  final double? averageRating;
  final int? ratingCount;
  final String? bestTimeToVisit;
  final String? duration;
  final String? location;
  final List<dynamic>? highlights;
  final String? currency;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  // New fields
  final String? id;
  final String? osmId;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? category;
  final List<dynamic>? activities;
  final String? openingHours;
  final String? phone;
  final String? website;
  final String? email;
  final int? priceLevel;
  final List<dynamic>? facilities;
  final String? cuisine;
  final double? starRating;
  final List<dynamic>? images;

  const DestinationCard({
    super.key,
    required this.imagePath,
    required this.name,
    required this.country,
    this.cost,
    this.tags = const [],
    this.description,
    this.subtitle,
    this.trailing,
    this.onViewDetails,
    this.onTap,
    this.city,
    this.rating,
    this.averageRating,
    this.ratingCount,
    this.bestTimeToVisit,
    this.duration,
    this.location,
    this.highlights,
    this.currency,
    this.isFavorite = false,
    this.onFavoriteToggle,
    // New fields
    this.id,
    this.osmId,
    this.latitude,
    this.longitude,
    this.address,
    this.category,
    this.activities,
    this.openingHours,
    this.phone,
    this.website,
    this.email,
    this.priceLevel,
    this.facilities,
    this.cuisine,
    this.starRating,
    this.images,
  });

  @override
  State<DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<DestinationCard> {
  Widget _buildImage() {
    if (widget.imagePath.startsWith('http://') ||
        widget.imagePath.startsWith('https://')) {
      return Image.network(
        widget.imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 160,
        errorBuilder: (_, _, _) => Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.place_outlined, size: 48),
        ),
      );
    }
    // If it's an asset path, use Image.asset
    return Image.asset(
      widget.imagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 160,
      errorBuilder: (_, _, _) => Container(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.place_outlined, size: 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final handleTap =
        widget.onTap ??
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DestinationDetailScreen(
                destination: {
                  'id': widget.id,
                  'osm_id': widget.osmId,
                  'name': widget.name,
                  'image': widget.imagePath,
                  'area': widget.country,
                  'cost': widget.cost,
                  'tags': widget.tags,
                  'description': widget.description,
                  'average_rating':
                      widget.averageRating ?? widget.rating ?? 0.0,
                  'rating_count': widget.ratingCount ?? 0,
                  'latitude': widget.latitude,
                  'longitude': widget.longitude,
                  'address': widget.address,
                  'category': widget.category ?? '',
                  'activities': widget.activities ?? [],
                  'opening_hours': widget.openingHours ?? '',
                  'phone': widget.phone ?? '',
                  'website': widget.website ?? '',
                  'email': widget.email ?? '',
                  'price_level': widget.priceLevel,
                  'facilities': widget.facilities ?? [],
                  'cuisine': widget.cuisine ?? '',
                  'star_rating': widget.starRating,
                  'images': widget.images ?? [],
                },
              ),
            ),
          );
        };

    // Format cost in XAF/FCFA for display
    String? costFormatted;
    if (widget.cost != null) {
      costFormatted = '${widget.cost!.toStringAsFixed(0)} FCFA';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: handleTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 280,
                          height: 160,
                          child: _buildImage(),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            widget.city != null
                                                ? '${widget.city}, ${widget.country}'
                                                : widget.country,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              widget.trailing ?? const SizedBox.shrink(),
                            ],
                          ),
                          // Star rating row
                          if (widget.averageRating != null &&
                              widget.averageRating! > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.averageRating!.toStringAsFixed(1),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (widget.ratingCount != null &&
                                    widget.ratingCount! > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${widget.ratingCount})',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          // Cost in XAF
                          if (costFormatted != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.attach_money,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  costFormatted,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (widget.duration != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.duration!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (widget.tags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: widget.tags
                                  .map(
                                    (t) => Chip(
                                      label: Text(
                                        '#$t',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: EdgeInsets.zero,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          if (widget.description != null &&
                              widget.description!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              widget.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: handleTap,
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: const Text('View Details'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
