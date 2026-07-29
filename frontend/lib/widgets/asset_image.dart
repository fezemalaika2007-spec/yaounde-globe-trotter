import 'package:flutter/material.dart';

class AssetImageWidget extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;

  const AssetImageWidget({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.landscape_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        color: theme.colorScheme.primaryContainer,
        child: Center(
          child: Icon(
            fallbackIcon,
            size: 48,
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
