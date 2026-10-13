/// A restaurant, from `GET /restaurants` and `GET /restaurants/:id`:
/// `{ "id": 1, "name": "Bella Napoli", "isOpen": true }`
class Restaurant {
  const Restaurant({required this.id, required this.name, required this.isOpen});

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
        id: json['id'] as int,
        name: json['name'] as String,
        isOpen: json['isOpen'] as bool,
      );

  final int id;
  final String name;
  final bool isOpen;
}
