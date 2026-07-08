import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService session restoration', () {
    test('restores a session using the refresh token', () async {
      SharedPreferences.setMockInitialValues({
        'refresh_token': 'refresh-token',
      });

      final client = MockClient((request) async {
        expect(request.url.path, '/auth/refresh');
        expect(request.method, 'POST');
        expect(jsonDecode(request.body)['refresh_token'], 'refresh-token');

        return http.Response(
          jsonEncode({'access_token': 'new-access-token'}),
          200,
        );
      });

      final authService = AuthService(client: client);
      final restored = await authService.restoreSession();

      expect(restored, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), 'new-access-token');
      expect(prefs.getString('refresh_token'), 'refresh-token');
    });
  });
}
