import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaounde_trip/l10n/app_localizations.dart';
import 'package:yaounde_trip/screens/home_screen.dart';
import 'package:yaounde_trip/widgets/destination_grid.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final locale in [const Locale('en'), const Locale('fr')]) {
    for (final width in [320.0, 600.0, 1200.0]) {
      testWidgets(
        'home omits footer and featured destinations at $width in ${locale.languageCode}',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final requests = <Uri>[];
          final navigation = <int>[];
          await http.runWithClient(
            () async {
              await tester.pumpWidget(
                MaterialApp(
                  locale: locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: HomeScreen(
                      onLocaleChanged: (_) {},
                      onSwitchTab: navigation.add,
                    ),
                  ),
                ),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 500));

              final l10n = AppLocalizations.of(
                tester.element(find.byType(HomeScreen)),
              );
              expect(find.text('SMART TRAVEL PLATFORM'), findsNothing);
              expect(find.text('150+ Verified Destinations'), findsNothing);
              expect(find.text('contact@yaounde.trip'), findsNothing);
              expect(find.text('Featured Destinations'), findsNothing);
              expect(find.text('Destinations en vedette'), findsNothing);
              expect(find.byType(DestinationGrid), findsNothing);
              expect(find.byType(CircularProgressIndicator), findsNothing);
              expect(requests, isEmpty);
              expect(find.text('Yaounde.Trip'), findsOneWidget);
              expect(find.text(l10n.homeWhatYouCanDo), findsOneWidget);
              await tester.pumpAndSettle();

              for (final label in [
                l10n.startExploring,
                l10n.homeFeatureDiscoverTitle,
                l10n.homeFeatureRecommendTitle,
                l10n.homeFeaturePlanTitle,
                l10n.homeFeatureSaveTitle,
              ]) {
                final action = find.text(label);
                await tester.ensureVisible(action);
                await tester.pumpAndSettle();
                await tester.tap(action);
                await tester.pumpAndSettle();
              }
              expect(navigation, [1, 1, 2, 4, 3]);
              expect(requests, isEmpty);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
            },
            () => MockClient((request) async {
              requests.add(request.url);
              return http.Response(
                jsonEncode([
                  {
                    'id': 'museum',
                    'name': 'National Museum',
                    'description':
                        'Explore the art, culture, and history of Cameroon.',
                    'image': 'assets/images/home/hero_1.jpg',
                    'city': 'Yaounde',
                    'rating': 4.8,
                    'tags': ['culture'],
                  },
                ]),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          );
        },
      );
    }
  }
}
