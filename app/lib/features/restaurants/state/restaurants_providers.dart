import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/restaurant.dart';
import '../data/restaurants_repository.dart';

/// The restaurant list. Screens `ref.watch` it and get loading, data or
/// error states for free; `ref.invalidate(restaurantsProvider)` reloads it.
final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) {
  return ref.watch(restaurantsRepositoryProvider).getRestaurants();
});
