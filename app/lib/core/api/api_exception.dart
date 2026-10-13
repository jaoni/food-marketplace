/// The backend answered with an error status (4xx or 5xx).
///
/// The backend always sends errors as `{ "error": "..." }`, plus `details`
/// for invalid input (400).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.details = const []});

  factory ApiException.fromResponse(int statusCode, Object? body) {
    if (body is Map<String, dynamic> && body['error'] is String) {
      final details = (body['details'] as List<dynamic>? ?? const [])
          .map((d) => ApiErrorDetail.fromJson(d as Map<String, dynamic>))
          .toList();
      return ApiException(statusCode, body['error'] as String, details: details);
    }
    return ApiException(statusCode, 'Request failed with status $statusCode');
  }

  final int statusCode;
  final String message;
  final List<ApiErrorDetail> details;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// One invalid field, e.g. `{ "path": "email", "message": "Invalid email address" }`.
class ApiErrorDetail {
  const ApiErrorDetail({required this.path, required this.message});

  factory ApiErrorDetail.fromJson(Map<String, dynamic> json) => ApiErrorDetail(
        path: json['path'] as String,
        message: json['message'] as String,
      );

  final String path;
  final String message;
}

/// The request got no answer: no connection, the server is down, or it
/// took too long. Safe to retry.
class NetworkException implements Exception {
  NetworkException(this.message) : isTimeout = false;
  NetworkException.timeout()
      : message = 'The request timed out',
        isTimeout = true;

  final String message;
  final bool isTimeout;

  @override
  String toString() => 'NetworkException: $message';
}
