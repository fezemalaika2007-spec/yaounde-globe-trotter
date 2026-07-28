import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App launches and shows login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GlobeTrotterApp());
    await tester.pump();

    // The login screen should be visible with "Login" text
    expect(find.text('Login'), findsWidgets);
  });
}
