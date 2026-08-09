import 'package:flutter/material.dart';
import 'asset_image.dart';
import 'settings_button.dart';

class AuthBackground extends StatelessWidget {
  final String backgroundPath;
  final String title;
  final Widget child;
  final void Function(Locale) onLocaleChanged;

  const AuthBackground({
    super.key,
    required this.backgroundPath,
    required this.title,
    required this.child,
    required this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 0.0,
                color: Colors.black,
              ),
              Shadow(
                offset: Offset(1, 0),
                blurRadius: 0.0,
                color: Colors.black,
              ),
              Shadow(
                offset: Offset(-1, 0),
                blurRadius: 0.0,
                color: Colors.black,
              ),
              Shadow(
                offset: Offset(0, -1),
                blurRadius: 0.0,
                color: Colors.black,
              ),
            ],
          ),
        ),
        actions: [SettingsButton(onLocaleChanged: onLocaleChanged)],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AssetImageWidget(
            path: backgroundPath,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            fallbackIcon: Icons.travel_explore,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
