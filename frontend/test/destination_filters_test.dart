import 'package:flutter_test/flutter_test.dart';
import 'package:yaounde_trip/utils/destination_filters.dart';

void main() {
  group('hasGoodName', () {
    test('accepts real destination names', () {
      expect(hasGoodName('Mefou National Park'), isTrue);
      expect(hasGoodName('Basilique Marie-Reine-des-Apôtres'), isTrue);
      expect(hasGoodName('Marché Central'), isTrue);
    });

    test('rejects generic OSM labels', () {
      expect(hasGoodName('Road'), isFalse);
      expect(hasGoodName('unnamed'), isFalse);
      expect(hasGoodName('Street'), isFalse);
      expect(hasGoodName('Bridge'), isFalse);
      expect(hasGoodName('Path'), isFalse);
      expect(hasGoodName('Roundabout'), isFalse);
    });

    test('rejects names shorter than 4 characters', () {
      expect(hasGoodName('ABC'), isFalse);
      expect(hasGoodName('Yo'), isFalse);
    });
  });

  group('isValidImageUrl', () {
    test('accepts http(s) URLs with image extensions', () {
      expect(isValidImageUrl('https://example.com/photo.jpg'), isTrue);
      expect(isValidImageUrl('http://example.com/photo.png'), isTrue);
      expect(isValidImageUrl('https://example.com/photo.jpeg'), isTrue);
      expect(isValidImageUrl('https://example.com/photo.webp'), isTrue);
    });

    test('rejects empty or non-image URLs', () {
      expect(isValidImageUrl(''), isFalse);
      expect(isValidImageUrl('not-a-url'), isFalse);
      expect(isValidImageUrl('https://example.com/page.html'), isFalse);
    });
  });

  group('normalizeImageUrl', () {
    test('strips query strings', () {
      final result = normalizeImageUrl(
        'https://example.com/photo.jpg?v=123&token=abc',
      );
      expect(result, 'https://example.com/photo.jpg');
    });

    test('strips fragments', () {
      final result = normalizeImageUrl('https://example.com/photo.jpg#section');
      expect(result, 'https://example.com/photo.jpg');
    });

    test('lowercases scheme and netloc', () {
      final result = normalizeImageUrl('HTTP://EXAMPLE.COM/Photo.JPG');
      expect(result, 'http://example.com/Photo.JPG');
    });

    test('removes trailing slash', () {
      final result = normalizeImageUrl('https://example.com/path/');
      expect(result, 'https://example.com/path');
    });
  });

  group('uniqueImages', () {
    test('deduplicates identical URLs', () {
      final result = uniqueImages([
        'https://example.com/a.jpg',
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ]);
      expect(result.length, 2);
      expect(result, contains('https://example.com/a.jpg'));
      expect(result, contains('https://example.com/b.jpg'));
    });

    test('deduplicates URLs with different query strings', () {
      final result = uniqueImages([
        'https://example.com/a.jpg?v=1',
        'https://example.com/a.jpg?v=2',
        'https://example.com/b.jpg',
      ]);
      expect(result.length, 2);
    });

    test('uses fallback when images list is empty', () {
      final result = uniqueImages(
        [],
        fallback: 'https://example.com/fallback.jpg',
      );
      expect(result, ['https://example.com/fallback.jpg']);
    });

    test('returns empty when nothing is provided', () {
      expect(uniqueImages([]), isEmpty);
    });
  });

  group('normalizeDestinationKey', () {
    test('uses id when present', () {
      final dest = {'id': 'uuid-123', 'name': 'Test Place'};
      expect(normalizeDestinationKey(dest), 'uuid-123');
    });

    test('uses osm_id when id is missing', () {
      final dest = {'osm_id': 'node/12345', 'name': 'Test Place'};
      expect(normalizeDestinationKey(dest), 'osm:node/12345');
    });

    test('falls back to name|image when both are present', () {
      final dest = {
        'name': 'Test Place',
        'image': 'https://example.com/photo.jpg',
      };
      final key = normalizeDestinationKey(dest);
      expect(key, contains('test place'));
      expect(key, contains('example.com'));
    });
  });
}
