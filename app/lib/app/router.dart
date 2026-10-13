import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/async_value_view.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/auth/ui/account_screen.dart';
import '../features/auth/ui/auth_form.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/cart/ui/cart_screen.dart';
import '../features/menu/ui/menu_screen.dart';
import '../features/orders/data/order.dart';
import '../features/orders/ui/order_screen.dart';
import '../features/orders/ui/orders_list_screen.dart';
import '../features/restaurants/ui/restaurant_list_screen.dart';

/// Pages you must be logged in to see. Browsing restaurants and menus is open
/// to everyone, like on the backend.
bool _needsLogin(String path) => path.startsWith('/account') || path.startsWith('/orders');

/// All screens and their URLs live here.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    // Runs before every navigation.
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading) return null; // still reading the saved session

      final loggedIn = auth.value != null;
      final path = state.uri.path;

      if (!loggedIn && _needsLogin(path)) {
        final expired = ref.read(authControllerProvider.notifier).sessionExpired;
        return Uri(path: '/login', queryParameters: {
          'from': state.uri.toString(),
          if (expired) 'expired': '1',
        }).toString();
      }
      if (loggedIn && (path == '/login' || path == '/register')) {
        return afterLoginPath(state.uri.queryParameters['from']);
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const RestaurantListScreen(),
        // Nested under '/', so these screens get a back button to the list.
        routes: [
          GoRoute(
            path: 'restaurants/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id']!);
              return id == null ? const _NotFoundScreen() : MenuScreen(restaurantId: id);
            },
          ),
          GoRoute(
            path: 'login',
            builder: (context, state) => LoginScreen(
              from: state.uri.queryParameters['from'],
              sessionExpired: state.uri.queryParameters['expired'] == '1',
            ),
          ),
          GoRoute(
            path: 'register',
            builder: (context, state) => RegisterScreen(from: state.uri.queryParameters['from']),
          ),
          GoRoute(path: 'account', builder: (context, state) => const AccountScreen()),
          GoRoute(path: 'cart', builder: (context, state) => const CartScreen()),
          GoRoute(
            path: 'orders',
            builder: (context, state) => const OrdersListScreen(),
            // Nested: an order's back button leads to the list.
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id']!);
                  if (id == null) return const _NotFoundScreen();
                  return OrderScreen(orderId: id, placedOrder: state.extra as OrderDetail?);
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );

  // When the backend rejects our token (e.g. it expired), the auth controller
  // logs out. Then show the login screen, and come back here afterwards.
  ref.listen(authControllerProvider, (previous, next) {
    final loggedOut = previous?.value != null && next.value == null;
    if (loggedOut && ref.read(authControllerProvider.notifier).sessionExpired) {
      router.go(Uri(path: '/login', queryParameters: {
        'from': router.state.uri.toString(),
        'expired': '1',
      }).toString());
    }
  });
  ref.onDispose(router.dispose);

  return router;
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const MessageView(icon: Icons.search_off, message: 'Page not found.'),
    );
  }
}
