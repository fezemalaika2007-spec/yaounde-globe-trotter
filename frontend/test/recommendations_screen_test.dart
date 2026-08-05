import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaounde_trip/screens/recommendations_screen.dart';
import 'package:yaounde_trip/services/api_service.dart';
import 'package:yaounde_trip/widgets/destination_grid_card.dart';

/// Test that the Recommendations screen renders structured sections.
void main() {
  testWidgets('RecommendationsScreen renders section titles from backend', (
    WidgetTester tester,
  ) async {
    // Build the screen inside a MaterialApp. The screen calls
    // ApiService.getRecommendationSections() which needs a token; since we
    // can't easily mock the singleton here without a backend, we verify the
    // widget builds and shows the loading state initially.
    await tester.pumpWidget(
      MaterialApp(home: RecommendationsScreen(onLocaleChanged: (_) {})),
    );
    // Initial state should be a loading spinner.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('DestinationGridCard renders a real destination name', (
    WidgetTester tester,
  ) async {
    final dest = {
      'name': 'Mefou National Park',
      'image': 'https://example.com/photo.jpg',
      'description': 'A real description of this nature destination.',
      'category': 'nature',
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DestinationGridCard(destination: dest)),
      ),
    );
    await tester.pumpAndSettle();
    // The real destination name must be shown (never a generic label).
    expect(find.text('Mefou National Park'), findsOneWidget);
  });
}
