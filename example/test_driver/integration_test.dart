import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  return await integrationDriver(
    onScreenshot:
        (String name, List<int> image, [Map<String, Object?>? args]) async {
      final File imageFile = await File(
        'screenshots/$name.png',
      ).create(recursive: true);
      imageFile.writeAsBytesSync(image);
      return true;
    },
  );
}