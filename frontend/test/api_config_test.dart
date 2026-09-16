import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaounde_trip/config/api_config.dart';

void main() {
  const expectedBaseUrl = String.fromEnvironment(
    'EXPECTED_API_BASE_URL',
    defaultValue: 'https://yaoundeglobe.duckdns.org/api',
  );

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in TargetPlatform.values) {
    test('uses the configured VPS gateway on ${platform.name}', () {
      debugDefaultTargetPlatformOverride = platform;

      expect(ApiConfig.baseUrl, expectedBaseUrl);
      expect(
        Uri.parse(ApiConfig.baseUrl).scheme,
        Uri.parse(expectedBaseUrl).scheme,
      );
      expect(ApiConfig.baseUrl.endsWith('/'), isFalse);
    });
  }
}
