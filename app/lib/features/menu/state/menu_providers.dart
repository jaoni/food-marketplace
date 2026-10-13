import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../restaurants/data/restaurant.dart';
import '../../restaurants/data/restaurants_repository.dart';
import '../data/menu.dart';
import '../data/menu_repository.dart';

/// Everything the menu screen shows: the restaurant (name, open or closed)
/// and its menu.
class RestaurantMenu {
  const RestaurantMenu({required this.restaurant, required this.menu});

  final Restaurant restaurant;
  final Menu menu;
}

/// `family`: one provider per restaurant id. `autoDispose`: forgotten when
/// the screen closes, so opening it again loads fresh data.
final restaurantMenuProvider =
    FutureProvider.autoDispose.family<RestaurantMenu, int>((ref, restaurantId) async {
  final restaurant = await ref.watch(restaurantsRepositoryProvider).getRestaurant(restaurantId);
  final menu = await ref.watch(menuRepositoryProvider).getMenu(restaurantId);
  return RestaurantMenu(restaurant: restaurant, menu: menu);
});
