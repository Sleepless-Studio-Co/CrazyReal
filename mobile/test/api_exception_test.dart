import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/services/api_exception.dart';

void main() {
  group('buildApiException', () {
    test('keeps the server message for unauthorized responses', () {
      final error = buildApiException(
        http.Response(
          jsonEncode({'message': 'Google account email is not verified'}),
          401,
        ),
      );

      expect(error, isA<UnauthorizedException>());
      expect(error.statusCode, 401);
      expect(error.message, 'Google account email is not verified');
    });

    test('falls back to Unauthorized without a JSON message', () {
      final error = buildApiException(http.Response('', 401));

      expect(error, isA<UnauthorizedException>());
      expect(error.message, 'Unauthorized');
    });

    test('keeps the server message for other errors', () {
      final error = buildApiException(
        http.Response(
            jsonEncode({
              'message': ['first', 'second']
            }),
            400),
      );

      expect(error, isNot(isA<UnauthorizedException>()));
      expect(error.statusCode, 400);
      expect(error.message, 'first\nsecond');
    });
  });
}
