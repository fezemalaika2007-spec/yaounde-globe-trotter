import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaounde_trip/main.dart';

void main() {
  testWidgets('App launches and shows loading indicator', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const YaoundeTripApp());
    // Initial state shows loading indicator while locale and theme load
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
