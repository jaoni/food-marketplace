import '../api/api_exception.dart';

/// The one place that turns errors into short, friendly messages. Every
/// screen shows errors through this function.
String errorMessage(Object error) {
  return switch (error) {
    NetworkException(isTimeout: true) => 'The server is taking too long to answer. Please try again.',
    NetworkException() => "Can't reach the server. Check your internet connection and try again.",
    ApiException() => _messageForStatus(error),
    // The JSON didn't have the shape the models expect.
    FormatException() || TypeError() => 'The server sent an unexpected answer. Please try again later.',
    _ => 'Something went wrong. Please try again.',
  };
}

String _messageForStatus(ApiException error) {
  if (error.statusCode >= 500) {
    // Never show server internals; the backend logs the details itself.
    return 'Something went wrong on our side. Please try again in a moment.';
  }
  return switch (error.statusCode) {
    // Invalid input: the backend's validation (zod) lists the fields.
    400 when error.details.isNotEmpty => 'Please check: ${_fieldNames(error.details)}.',
    // The backend's 403 texts talk about roles, which users don't know about.
    403 => "Your account isn't allowed to do this.",
    // These come with a message written for people, e.g.
    // "Invalid email or password" (401), "Order not found" (404),
    // "Email is already registered" (409), "Green Garden is closed" (422).
    400 || 401 || 404 || 409 || 422 => error.message,
    _ => 'Something went wrong. Please try again.',
  };
}

/// "deliveryAddress" -> "delivery address", "items.0.quantity" -> "quantity".
String _fieldNames(List<ApiErrorDetail> details) {
  final names = <String>{
    for (final detail in details)
      if (detail.path.isEmpty)
        'your input'
      else
        detail.path
            .split('.')
            .lastWhere((part) => int.tryParse(part) == null, orElse: () => detail.path)
            .replaceAllMapped(RegExp('[A-Z]'), (match) => ' ${match[0]!.toLowerCase()}'),
  };
  return names.join(', ');
}
