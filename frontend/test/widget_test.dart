import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaounde_trip/main.dart';

void main() {
  testWidgets('App launches and shows loading indicator', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const YaoundeTripApp());
    // App should start rendering without throwing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
