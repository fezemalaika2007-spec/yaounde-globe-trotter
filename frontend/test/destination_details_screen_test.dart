import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaounde_trip/screens/destination_details_screen.dart';

void main() {
  testWidgets('DestinationDetailScreen deduplicates images and shows caption', (
    WidgetTester tester,
  ) async {
    final dest = {
      'name': 'Test Place',
      'images': [
        'https://example.com/a.jpg',
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ],
      'image': '',
      'description': 'A nice place to visit',
      'category': 'Park',
      'address': '123 Street',
      'latitude': 3.0,
      'longitude': 11.0,
    };

    await tester.pumpWidget(
      MaterialApp(home: DestinationDetailScreen(destination: dest)),
    );
    await tester.pumpAndSettle();

    // Caption should indicate there are 2 unique images and show Image 1 of 2
    final captionFinder = find.byWidgetPredicate(
      (w) => w is Text && w.data != null && w.data!.contains('Image 1 of 2'),
    );
    expect(captionFinder, findsOneWidget);

    // Name should be visible
    expect(find.text('Test Place'), findsOneWidget);
  });
}
