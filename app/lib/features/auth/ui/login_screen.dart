import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_message.dart';
import '../state/auth_controller.dart';
import 'auth_form.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from, this.sessionExpired = false});

  /// Where to go after logging in (the page that needed a login).
  final String? from;
  final bool sessionExpired;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(email: _email.text.trim(), password: _password.text);
      if (mounted) context.go(afterLoginPath(widget.from));
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: AuthForm(
        formKey: _formKey,
        notice: widget.sessionExpired ? 'Your session has expired. Please log in again.' : null,
        error: _error,
        fields: [
          EmailField(controller: _email),
          PasswordField(controller: _password, onSubmitted: _submit),
        ],
        submitLabel: 'Log in',
        submitting: _submitting,
        onSubmit: _submit,
        footer: TextButton(
          onPressed: () => context.go(authPath('/register', from: widget.from)),
          child: const Text('No account yet? Sign up'),
        ),
      ),
    );
  }
}
