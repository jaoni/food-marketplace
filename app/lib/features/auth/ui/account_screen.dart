import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/async_value_view.dart';
import '../state/auth_controller.dart';

/// Who you're logged in as, straight from the server (`GET /auth/me`).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: AsyncValueView(
        value: ref.watch(currentUserProvider),
        onRetry: () => ref.invalidate(currentUserProvider),
        data: (user) => ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(user.name),
              subtitle: Text(user.email),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Member since'),
              subtitle: Text(MaterialLocalizations.of(context).formatMediumDate(user.createdAt.toLocal())),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                onPressed: () {
                  final auth = ref.read(authControllerProvider.notifier);
                  context.go('/');
                  auth.logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
