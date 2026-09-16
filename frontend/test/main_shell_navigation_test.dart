import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaounde_trip/l10n/app_localizations.dart';
import 'package:yaounde_trip/screens/main_shell.dart';
import 'package:yaounde_trip/services/notification_provider.dart';

import 'chat_test_helpers.dart';

Future<void> _pumpNavigation(WidgetTester tester) async {
  // The home footer animates continuously, so this screen never settles.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    addTearDown(NotificationProvider().stopPolling);
  });

  for (final width in [360.0, 844.0, 1200.0]) {
    testWidgets('navigation works without a bottom bar at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MainShell(onLocaleChanged: (_) {}),
          ),
        );
        await _pumpNavigation(tester);

        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(BottomNavigationBar), findsNothing);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.bottomNavigationBar, isNull);

        if (width < 850) {
          expect(scaffold.drawer, isNotNull);
          await tester.tap(find.byTooltip('Open navigation menu'));
          await _pumpNavigation(tester);
          await tester.tap(find.widgetWithText(ListTile, 'Destinations'));
          await _pumpNavigation(tester);
        } else {
          expect(scaffold.drawer, isNull);
          await tester.tap(find.widgetWithText(ListTile, 'Destinations'));
          await _pumpNavigation(tester);
        }
        expect(find.text('Yaounde.Trip · Destinations'), findsOneWidget);
        final stack = tester.widget<IndexedStack>(
          find.byType(IndexedStack).first,
        );
        expect(stack.index, 1);
        expect(stack.children[1], isNot(isA<SizedBox>()));
        expect(find.byType(TextField), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        NotificationProvider().stopPolling();
        await tester.pump();
      }, () => MockClient((_) async => chatResponse([])));
    });
  }
}
