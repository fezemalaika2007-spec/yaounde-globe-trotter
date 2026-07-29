import 'package:flutter/material.dart';
import 'asset_image.dart';

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
  final String? bestTimeToVisit;
  final String? duration;
  final String? location;
  final List<dynamic>? highlights;
  final String? currency;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

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
    this.bestTimeToVisit,
    this.duration,
    this.location,
    this.highlights,
    this.currency,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  State<DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<DestinationCard> {
  void _showDetailsSheet(BuildContext context) {
    final theme = Theme.of(context);
    final l10nCost = widget.cost != null
        ? '\$${widget.cost}/${widget.currency ?? 'USD'}/day'
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 200,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: AssetImageWidget(
                          path: widget.imagePath,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.place_outlined,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton.filled(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  if (widget.onFavoriteToggle != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: IconButton.filled(
                        icon: Icon(
                          widget.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                        onPressed: () => widget.onFavoriteToggle!(),
                        style: IconButton.styleFrom(
                          backgroundColor: widget.isFavorite
                              ? Colors.red
                              : Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.name,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      widget.city != null
                                          ? '${widget.city}, ${widget.country}'
                                          : widget.country,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (l10nCost != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              l10nCost,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (widget.rating != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            widget.rating!.toStringAsFixed(1),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.tags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: widget.tags
                            .map(
                              (t) => Chip(
                                label: Text('#$t'),
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (widget.bestTimeToVisit != null ||
                        widget.duration != null ||
                        widget.location != null) ...[
                      const SizedBox(height: 20),
                      _InfoRow(
                        icon: Icons.calendar_today,
                        label: 'Best time to visit',
                        value: widget.bestTimeToVisit,
                      ),
                      _InfoRow(
                        icon: Icons.schedule,
                        label: 'Duration',
                        value: widget.duration,
                      ),
                      _InfoRow(
                        icon: Icons.place,
                        label: 'Location',
                        value: widget.location,
                      ),
                    ],
                    if (widget.highlights != null &&
                        widget.highlights!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Highlights',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: widget.highlights!
                            .map(
                              (h) => Chip(
                                label: Text(h),
                                avatar: const Icon(
                                  Icons.check_circle,
                                  size: 18,
                                ),
                                backgroundColor:
                                    theme.colorScheme.tertiaryContainer,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (widget.description != null &&
                        widget.description!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'About',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.description!,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        if (widget.onFavoriteToggle != null)
                          Tooltip(
                            message: widget.isFavorite
                                ? 'Favorited'
                                : 'Add to favorites',
                            child: IconButton.filledTonal(
                              onPressed: () => widget.onFavoriteToggle!(),
                              icon: Icon(
                                widget.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Added "${widget.name}" to your trip plans!',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.bookmark_add),
                              label: const Text('Add to Itinerary'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final handleTap =
        widget.onTap ??
        widget.onViewDetails ??
        () => _showDetailsSheet(context);

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
            // --- Image and content in a centered fixed-width column ---
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
                          child: AssetImageWidget(
                            path: widget.imagePath,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.place_outlined,
                          ),
                        ),
                      ),
                    ),
                    // Content below image — same width as image
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

/// A reusable info row for the details sheet.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _InfoRow({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
