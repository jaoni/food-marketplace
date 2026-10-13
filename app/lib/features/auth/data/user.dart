/// The four roles the backend knows. The JSON uses snake_case names.
enum UserRole {
  customer('customer'),
  restaurantOwner('restaurant_owner'),
  courier('courier'),
  admin('admin');

  const UserRole(this.json);
  final String json;

  static UserRole fromJson(String value) => values.firstWhere(
        (role) => role.json == value,
        orElse: () => throw FormatException('Unknown role: $value'),
      );
}

/// A user, from `GET /auth/me` and inside login/register responses:
/// `{ "id", "email", "name", "role", "createdAt" }`
class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        email: json['email'] as String,
        name: json['name'] as String,
        role: UserRole.fromJson(json['role'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final int id;
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.json,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// A logged-in session. `POST /auth/login` and `POST /auth/register` answer
/// with exactly this shape, `{ "token", "user" }`, and the app saves it on
/// the device (as the same JSON) to stay logged in.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String token;
  final User user;

  Map<String, dynamic> toJson() => {'token': token, 'user': user.toJson()};
}
