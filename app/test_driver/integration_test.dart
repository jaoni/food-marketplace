import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Runs on your computer while `flutter drive` runs an integration test on a
/// simulator or device. Saves the screenshots the test takes into
/// build/screenshots/.
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final file = File('build/screenshots/$name.png');
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);
        return true;
      },
    );
