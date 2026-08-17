import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaounde_trip/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches and shows loading indicator', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const YaoundeTripApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
