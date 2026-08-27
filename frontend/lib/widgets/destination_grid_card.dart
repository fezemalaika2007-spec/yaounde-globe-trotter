import 'package:flutter/material.dart';
import '../screens/destination_details_screen.dart';
import '../utils/destination_filters.dart';

/// A compact, image-forward card for use in a responsive grid layout.
///
/// Shows the destination image with a rating overlay, name below, and
/// optional tag chips. Tapping navigates to [DestinationDetailScreen].
class DestinationGridCard extends StatefulWidget {
  final Map<String, dynamic> destination;

  const DestinationGridCard({super.key, required this.destination});

  @override
  State<DestinationGridCard> createState() => _DestinationGridCardState();
}

class _DestinationGridCardState extends State<DestinationGridCard> {
  bool _hovered = false;

  void _openDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DestinationDetailScreen(destination: widget.destination),
      ),
    );
  }

  IconData _getCategoryIcon(String category, List<dynamic> tags) {
    final cat = category.toLowerCase();
    final tagsStr = tags.join(' ').toLowerCase();
    if (cat.contains('nature') || tagsStr.contains('nature') || tagsStr.contains('park')) {
      return Icons.forest_outlined;
    }
    if (cat.contains('culture') || cat.contains('history') || tagsStr.contains('museum') || tagsStr.contains('culture')) {
      return Icons.account_balance_outlined;
    }
    if (cat.contains('shop') || tagsStr.contains('market') || tagsStr.contains('shopping')) {
      return Icons.storefront_outlined;
    }
    if (cat.contains('food') || tagsStr.contains('food') || tagsStr.contains('dining')) {
      return Icons.restaurant_outlined;
    }
    if (cat.contains('hotel') || tagsStr.contains('accommodation') || tagsStr.contains('hotel')) {
      return Icons.hotel_outlined;
    }
    return Icons.location_on_outlined;
  }

  Widget _buildIconContainer(
    String category,
    List<dynamic> tags,
    ThemeData theme,
  ) {
    return Container(
      color: theme.colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          _getCategoryIcon(category, tags),
          size: 36,
          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildCardImage({
    required String imageUrl,
    required String name,
    required String category,
    required List<dynamic> tags,
    required ThemeData theme,
  }) {
    final cleanUrl = imageUrl.trim().replaceAll('\\', '/');
    final localFallback = getLocalAssetFallback(name);

    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return Image.network(
        cleanUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: theme.colorScheme.primaryContainer,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          if (localFallback.isNotEmpty) {
            return Image.asset(
              localFallback,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) =>
                  _buildIconContainer(category, tags, theme),
            );
          }
          return _buildIconContainer(category, tags, theme);
        },
      );
    }

    final effectiveAsset = cleanUrl.isNotEmpty
        ? (cleanUrl.startsWith('assets/')
            ? cleanUrl
            : 'assets/images/$cleanUrl')
        : localFallback;

    if (effectiveAsset.isNotEmpty) {
      return Image.asset(
        effectiveAsset,
        fit: BoxFit.cover,
        errorBuilder: (context, err, stack) {
          if (localFallback.isNotEmpty && localFallback != effectiveAsset) {
            return Image.asset(
              localFallback,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) =>
                  _buildIconContainer(category, tags, theme),
            );
          }
          return _buildIconContainer(category, tags, theme);
        },
      );
    }

    return _buildIconContainer(category, tags, theme);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.destination;
    final name = d['name'] ?? '';
    final imageUrl = resolveDestinationImageUrl(d);
    final avgRating = (d['average_rating'] ?? 0).toDouble();
    final ratingCount = d['rating_count'] ?? 0;
    final cost = d['cost'];
    final tags = (d['tags'] as List<dynamic>?) ?? [];
    final category = (d['category'] ?? '').toString();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _openDetails,
        onTapDown: (_) => setState(() => _hovered = true),
        onTapUp: (_) => setState(() => _hovered = false),
        onTapCancel: () => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _hovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Image section ---
                  AspectRatio(
                    aspectRatio: 1.6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: _buildCardImage(
                            imageUrl: imageUrl,
                            name: name,
                            category: category,
                            tags: tags,
                            theme: theme,
                          ),
                        ),
                        // Gradient overlay at bottom for readability
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Rating badge
                        if (avgRating > 0)
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 12,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    avgRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (ratingCount > 0) ...[
                                    const SizedBox(width: 2),
                                    Text(
                                      '($ratingCount)',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        // Cost badge
                        if (cost != null)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.85,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$cost FCFA',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // --- Name + tags below image ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: tags.take(3).map((t) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#$t',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
