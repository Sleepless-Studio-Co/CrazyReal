import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String? message])
      : super(message ?? 'Unauthorized', statusCode: 401);
}

/// Thrown when the user dismisses the native Google sign-in sheet. Callers
/// typically clear their loading state without showing an error.
class GoogleSignInCancelledException implements Exception {
  @override
  String toString() => 'Google sign-in cancelled';
}

ApiException buildApiException(http.Response response) {
  final message = _extractMessage(response.body);

  // Keep the UnauthorizedException type so callers can trigger a re-auth,
  // while preserving the server message (e.g. "Invalid Google token").
  if (response.statusCode == 401) {
    return UnauthorizedException(message);
  }

  return ApiException(
    message ?? 'Erreur serveur (${response.statusCode})',
    statusCode: response.statusCode,
  );
}

String? _extractMessage(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    final rawMessage = decoded['message'];
    final message =
        rawMessage is List ? rawMessage.join('\n') : rawMessage?.toString();
    return message == null || message.isEmpty ? null : message;
  } catch (_) {
    return null;
  }
}
