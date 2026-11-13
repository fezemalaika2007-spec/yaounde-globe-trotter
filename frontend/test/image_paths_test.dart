import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaounde_trip/utils/image_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('authentication background image is bundled and loadable', () async {
    expect(ImagePaths.loginBackground, 'assets/images/auth/78.jpg');
    expect(ImagePaths.registerBackground, 'assets/images/auth/78.jpg');

    final image = await rootBundle.load(ImagePaths.loginBackground);
    expect(image.lengthInBytes, greaterThan(0));
  });
}
