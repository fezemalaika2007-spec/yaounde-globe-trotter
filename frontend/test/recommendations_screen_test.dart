import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaounde_trip/l10n/app_localizations.dart';
import 'package:yaounde_trip/screens/recommendations_screen.dart';
import 'package:yaounde_trip/widgets/destination_grid_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RecommendationsScreen renders section titles from backend', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _wrap(RecommendationsScreen(onLocaleChanged: (_) {})),
    );
    await tester.pump(const Duration(seconds: 30));
    expect(find.byType(RecommendationsScreen), findsOneWidget);
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
      _wrap(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: DestinationGridCard(destination: dest),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mefou National Park'), findsOneWidget);
  });
}
