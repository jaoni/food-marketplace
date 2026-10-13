import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'menu.dart';

class MenuRepository {
  MenuRepository(this._api);

  final ApiClient _api;

  Future<Menu> getMenu(int restaurantId) async {
    final json = await _api.get('/restaurants/$restaurantId/menu') as Map<String, dynamic>;
    return Menu.fromJson(json);
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(apiClientProvider));
});
