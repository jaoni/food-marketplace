import 'package:flutter/material.dart';

/// The login or register path, remembering where to go afterwards.
String authPath(String path, {String? from}) =>
    Uri(path: path, queryParameters: {if (from != null) 'from': from}).toString();

/// Where to go after logging in: back to the page that asked for it, or home.
String afterLoginPath(String? from) => from != null && from.startsWith('/') ? from : '/';

/// The shared layout of the login and register screens.
class AuthForm extends StatelessWidget {
  const AuthForm({
    super.key,
    required this.formKey,
    required this.fields,
    required this.submitLabel,
    required this.submitting,
    required this.onSubmit,
    required this.footer,
    this.notice,
    this.error,
  });

  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final String submitLabel;
  final bool submitting;
  final VoidCallback onSubmit;
  final Widget footer;
  final String? notice;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (notice != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(notice!),
            ),
            const SizedBox(height: 16),
          ],
          for (final field in fields) ...[field, const SizedBox(height: 12)],
          if (error != null) ...[
            Text(error!, style: TextStyle(color: colors.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            // Disabled while sending, so it can't be tapped twice.
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(submitLabel),
          ),
          const SizedBox(height: 8),
          footer,
        ],
      ),
    );
  }
}

class EmailField extends StatelessWidget {
  const EmailField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(labelText: 'Email'),
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      validator: (value) => value!.contains('@') ? null : 'Enter a valid email',
    );
  }
}

class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.isNew = false,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  /// A new password (sign up) must be 8 to 72 characters, like the backend requires.
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Password',
        helperText: isNew ? 'At least 8 characters' : null,
      ),
      obscureText: true,
      textInputAction: TextInputAction.done,
      autofillHints: [isNew ? AutofillHints.newPassword : AutofillHints.password],
      onFieldSubmitted: (_) => onSubmitted(),
      validator: (value) {
        if (value!.isEmpty) return 'Enter your password';
        if (isNew && value.length < 8) return 'Use at least 8 characters';
        if (isNew && value.length > 72) return 'Use at most 72 characters';
        return null;
      },
    );
  }
}
