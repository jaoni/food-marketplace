import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'restaurant.dart';

/// Gets restaurants from the backend and turns the JSON into models.
/// Like a backend repository: data access only, no UI and no app rules.
class RestaurantsRepository {
  RestaurantsRepository(this._api);

  final ApiClient _api;

  Future<List<Restaurant>> getRestaurants() async {
    final json = await _api.get('/restaurants') as List<dynamic>;
    return json.map((r) => Restaurant.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Restaurant> getRestaurant(int id) async {
    final json = await _api.get('/restaurants/$id') as Map<String, dynamic>;
    return Restaurant.fromJson(json);
  }
}

final restaurantsRepositoryProvider = Provider<RestaurantsRepository>((ref) {
  return RestaurantsRepository(ref.watch(apiClientProvider));
});
