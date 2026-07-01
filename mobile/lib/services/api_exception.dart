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
  UnauthorizedException() : super('Unauthorized', statusCode: 401);
}

ApiException buildApiException(http.Response response) {
  if (response.statusCode == 401) {
    return UnauthorizedException();
  }

  try {
    final body = jsonDecode(response.body);
    final rawMessage = body['message'];
    final message = rawMessage is List ? rawMessage.join('\n') : rawMessage?.toString();
    return ApiException(
      message ?? 'Erreur serveur (${response.statusCode})',
      statusCode: response.statusCode,
    );
  } catch (_) {
    return ApiException('Erreur serveur (${response.statusCode})', statusCode: response.statusCode);
  }
}
