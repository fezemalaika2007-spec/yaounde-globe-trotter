import 'package:flutter/material.dart';
import 'destination_grid_card.dart';

/// A responsive grid of destination cards for browsing-style pages.
///
/// Uses [LayoutBuilder] to adapt the column count:
/// - ≤600px → 2 columns (mobile)
/// - ≤900px → 3 columns (tablet)
/// - >900px → 4 columns (desktop)
///
/// Each cell uses [DestinationGridCard] for a compact, image-forward
/// presentation. Tapping any card navigates to the detail screen.
///
/// This widget is designed to be **reusable** — it can be dropped into
/// Recommendations, Itineraries (gallery view), or any other page that
/// needs a Pinterest-like grid of destinations.
class DestinationGrid extends StatelessWidget {
  final List<Map<String, dynamic>> destinations;

  /// When true, the grid sizes itself to its content so it can be placed
  /// inside a scrollable parent (e.g. the Home screen's featured section).
  final bool shrinkWrap;

  /// When [shrinkWrap] is true and [scrollable] is false, the grid does not
  /// scroll independently so the parent scroll view owns the scroll gesture.
  final bool scrollable;

  const DestinationGrid({
    super.key,
    required this.destinations,
    this.shrinkWrap = false,
    this.scrollable = false,
  });

  int _columnCount(double width) {
    if (width <= 600) return 2;
    if (width <= 900) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);
        final crossAxisSpacing = 12.0;
        final mainAxisSpacing = 12.0;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: 0.72,
          ),
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap && !scrollable
              ? const NeverScrollableScrollPhysics()
              : null,
          itemCount: destinations.length,
          itemBuilder: (context, index) {
            return DestinationGridCard(destination: destinations[index]);
          },
        );
      },
    );
  }
}
