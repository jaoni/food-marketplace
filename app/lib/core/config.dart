import 'package:flutter/foundation.dart';

/// Where the backend runs. Override it with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
String get apiBaseUrl {
  const fromDefine = String.fromEnvironment('API_BASE_URL');
  if (fromDefine.isNotEmpty) return fromDefine;

  // The Android emulator reaches your computer at 10.0.2.2. The iOS
  // simulator shares your computer's network, so localhost works there.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://localhost:3000';
}
