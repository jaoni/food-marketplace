import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_message.dart';
import '../../auth/state/auth_controller.dart';
import '../../auth/ui/auth_form.dart';
import '../state/checkout_controller.dart';

/// Delivery address and the "Place order" button, shown below the cart.
class CheckoutSection extends ConsumerStatefulWidget {
  const CheckoutSection({super.key});

  @override
  ConsumerState<CheckoutSection> createState() => _CheckoutSectionState();
}

class _CheckoutSectionState extends ConsumerState<CheckoutSection> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final order = await ref.read(checkoutControllerProvider.notifier).placeOrder(_address.text.trim());
    if (order != null && mounted) {
      context.go('/orders/${order.id}', extra: order);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(authControllerProvider.select((session) => session.value != null));
    if (!loggedIn) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () => context.push(authPath('/login', from: '/cart')),
          child: const Text('Log in to place your order'),
        ),
      );
    }

    final checkout = ref.watch(checkoutControllerProvider);
    final colors = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _address,
              enabled: !checkout.sending,
              decoration: const InputDecoration(labelText: 'Delivery address'),
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.fullStreetAddress],
              validator: (value) {
                final address = value!.trim();
                if (address.isEmpty) return 'Enter a delivery address';
                if (address.length > 500) return 'Use at most 500 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (checkout.error != null) ...[
              Text(errorMessage(checkout.error!), style: TextStyle(color: colors.error)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              // Disabled while sending, so one tap can't become two orders.
              onPressed: checkout.sending ? null : _placeOrder,
              child: checkout.sending
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Placing order…'),
                      ],
                    )
                  : Text(checkout.error != null ? 'Try again' : 'Place order'),
            ),
          ],
        ),
      ),
    );
  }
}
