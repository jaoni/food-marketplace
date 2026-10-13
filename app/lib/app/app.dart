import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

class FoodApp extends ConsumerWidget {
  const FoodApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Food',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
