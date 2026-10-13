import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/async_value_view.dart';
import '../../cart/ui/cart_button.dart';
import '../data/restaurant.dart';
import '../state/restaurants_providers.dart';

class RestaurantListScreen extends ConsumerWidget {
  const RestaurantListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurants'),
        actions: [
          const CartButton(),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'My orders',
            onPressed: () => context.go('/orders'), // asks to log in first if needed
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Account',
            onPressed: () => context.push('/account'), // asks to log in first if needed
          ),
        ],
      ),
      body: AsyncValueView(
        value: ref.watch(restaurantsProvider),
        onRetry: () => ref.invalidate(restaurantsProvider),
        data: (restaurants) {
          if (restaurants.isEmpty) {
            return const MessageView(
              icon: Icons.storefront_outlined,
              message: 'No restaurants yet. Check back soon!',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(restaurantsProvider.future),
            child: ListView.separated(
              itemCount: restaurants.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => RestaurantTile(restaurant: restaurants[index]),
            ),
          );
        },
      ),
    );
  }
}

class RestaurantTile extends StatelessWidget {
  const RestaurantTile({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      leading: CircleAvatar(child: Text(restaurant.name[0])),
      title: Text(restaurant.name),
      subtitle: Text(restaurant.isOpen ? 'Open now' : 'Closed'),
      trailing: const Icon(Icons.chevron_right),
      // Closed restaurants can still be opened, to look at the menu.
      onTap: () => context.push('/restaurants/${restaurant.id}'),
    );

    // Closed restaurants are greyed out.
    return restaurant.isOpen ? tile : Opacity(opacity: 0.4, child: tile);
  }
}
