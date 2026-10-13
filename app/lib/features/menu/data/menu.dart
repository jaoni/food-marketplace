/// A restaurant's menu, from `GET /restaurants/:id/menu`:
/// `{ "restaurantId": 1, "categories": [{ "id", "name", "items": [...] }] }`
class Menu {
  const Menu({required this.restaurantId, required this.categories});

  factory Menu.fromJson(Map<String, dynamic> json) => Menu(
        restaurantId: json['restaurantId'] as int,
        categories: (json['categories'] as List<dynamic>)
            .map((c) => MenuCategory.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  final int restaurantId;
  final List<MenuCategory> categories;
}

class MenuCategory {
  const MenuCategory({required this.id, required this.name, required this.items});

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
        id: json['id'] as int,
        name: json['name'] as String,
        items: (json['items'] as List<dynamic>)
            .map((i) => MenuItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );

  final int id;
  final String name;
  final List<MenuItem> items;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.isAvailable,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as int,
        categoryId: json['categoryId'] as int,
        name: json['name'] as String,
        description: json['description'] as String,
        priceCents: json['priceCents'] as int,
        isAvailable: json['isAvailable'] as bool,
      );

  final int id;
  final int categoryId;
  final String name;
  final String description;
  final int priceCents; // whole cents, e.g. 1050 = 10.50
  final bool isAvailable;
}
