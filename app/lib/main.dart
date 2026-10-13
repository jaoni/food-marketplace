import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  runApp(
    ProviderScope(
      // Riverpod 3 retries failed providers automatically (up to 10 times,
      // showing "loading" meanwhile). Turned off: screens show the error
      // right away, with a "Try again" button.
      retry: (retryCount, error) => null,
      child: const FoodApp(),
    ),
  );
}
