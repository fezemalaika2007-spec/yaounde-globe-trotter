import 'package:flutter/material.dart';

/// An interactive or read-only star rating widget supporting 1 to 5 stars.
class StarRatingWidget extends StatefulWidget {
  final int initialRating;
  final double starSize;
  final bool isInteractive;
  final ValueChanged<int>? onRatingChanged;

  const StarRatingWidget({
    super.key,
    this.initialRating = 0,
    this.starSize = 28.0,
    this.isInteractive = true,
    this.onRatingChanged,
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  late int _rating;
  int _hoverRating = 0;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  @override
  void didUpdateWidget(StarRatingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRating != widget.initialRating) {
      setState(() => _rating = widget.initialRating);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = Colors.amber.shade600;
    final inactiveColor = Colors.grey.shade400;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        final isFilled = widget.isInteractive
            ? (_hoverRating >= starNumber || (_hoverRating == 0 && _rating >= starNumber))
            : _rating >= starNumber;

        return MouseRegion(
          onEnter: (_) {
            if (widget.isInteractive) {
              setState(() => _hoverRating = starNumber);
            }
          },
          onExit: (_) {
            if (widget.isInteractive) {
              setState(() => _hoverRating = 0);
            }
          },
          child: GestureDetector(
            onTap: widget.isInteractive
                ? () {
                    setState(() => _rating = starNumber);
                    widget.onRatingChanged?.call(starNumber);
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: AnimatedScale(
                scale: (widget.isInteractive && _hoverRating == starNumber) ? 1.25 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFilled ? activeColor : inactiveColor,
                  size: widget.starSize,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
