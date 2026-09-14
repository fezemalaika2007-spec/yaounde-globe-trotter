import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaounde_trip/screens/destination_details_screen.dart';
import 'package:yaounde_trip/utils/destination_filters.dart';

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

    // Name should be visible (appears in AppBar title and body headline)
    expect(find.text('Test Place'), findsAtLeastNWidgets(1));
  });

  testWidgets('gallery collapses URLs that differ only by query or case', (
    WidgetTester tester,
  ) async {
    final dest = {
      'name': 'Duplicate Image Place',
      'images': [
        'https://example.com/photo.jpg?v=1',
        'HTTPS://EXAMPLE.COM/photo.jpg?v=2',
        'https://example.com/photo.jpg#fragment',
        'https://example.com/other.png',
      ],
      'image': 'https://example.com/photo.jpg',
      'description': 'A long enough description for the destination.',
      'category': 'Park',
      'address': 'Yaoundé',
      'latitude': 3.0,
      'longitude': 11.0,
    };

    await tester.pumpWidget(
      MaterialApp(home: DestinationDetailScreen(destination: dest)),
    );
    await tester.pumpAndSettle();

    // Only 2 unique normalized images: photo.jpg and other.png
    final captionFinder = find.byWidgetPredicate(
      (w) => w is Text && w.data != null && w.data!.contains('Image 1 of 2'),
    );
    expect(captionFinder, findsOneWidget);
  });

  test('uniqueImages collapses normalized duplicates from backend', () {
    final result = uniqueImages([
      'https://upload.wikimedia.org/wikipedia/commons/2/20/Mus%C3%A9e_National_Yaound%C3%A9.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/2/20/Mus%C3%A9e_National_Yaound%C3%A9.jpg?width=400',
      'https://upload.wikimedia.org/wikipedia/commons/2/20/Mus%C3%A9e_National_Yaound%C3%A9.jpg',
    ], fallback: '');

    expect(result.length, 1);
  });
}
