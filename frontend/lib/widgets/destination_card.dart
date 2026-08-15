import 'package:flutter/material.dart';
import '../screens/destination_details_screen.dart';
import '../utils/destination_filters.dart';

class DestinationCard extends StatefulWidget {
  final String imagePath;
  final String name;
  final String country;
  final int? cost;
  final List<dynamic> tags;
  final String? description;
  final String? city;
  final double? averageRating;
  final int? ratingCount;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onTap;

  // Additional optional metadata used when opening details
  final dynamic id;
  final dynamic osmId;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? category;
  final List<dynamic>? activities;
  final String? openingHours;
  final String? phone;
  final String? website;
  final String? email;
  final dynamic priceLevel;
  final List<dynamic>? facilities;
  final String? cuisine;
  final dynamic starRating;
  final List<dynamic>? images;

  const DestinationCard({
    super.key,
    required this.imagePath,
    required this.name,
    required this.country,
    this.cost,
    this.tags = const [],
    this.description,
    this.city,
    this.averageRating,
    this.ratingCount,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.onTap,
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
    final formattedUrl = formatImageUrl(widget.imagePath);
    if (formattedUrl.startsWith('http://') ||
        formattedUrl.startsWith('https://')) {
      return Image.network(
        formattedUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 160,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.place_outlined, size: 48),
          );
        },
      );
    }
    return Image.asset(
      widget.imagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 160,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.place_outlined, size: 48),
        );
      },
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
                  'average_rating': widget.averageRating ?? 0.0,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: double.infinity,
                  height: 160,
                  child: _buildImage(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.city != null
                                  ? '${widget.city}, ${widget.country}'
                                  : widget.country,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          widget.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: widget.isFavorite ? Colors.red : null,
                        ),
                        onPressed: widget.onFavoriteToggle,
                      ),
                    ],
                  ),
                  if (widget.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
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
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (widget.description != null &&
                      widget.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
