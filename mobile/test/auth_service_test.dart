import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('AuthService session restoration', () {
    test('restores a session using the refresh token', () async {
      SharedPreferences.setMockInitialValues({});

      final secureStorage = FlutterSecureStorage(
        aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      );
      await secureStorage.write(key: 'refresh_token', value: 'refresh-token');

      final client = MockClient((request) async {
        expect(request.url.path, '/auth/refresh');
        expect(request.method, 'POST');
        expect(jsonDecode(request.body)['refresh_token'], 'refresh-token');

        return http.Response(
          jsonEncode({'access_token': 'new-access-token'}),
          200,
        );
      });

      final authService = AuthService(client: client, secureStorage: secureStorage);
      final restored = await authService.restoreSession();

      expect(restored, isTrue);

      expect(await secureStorage.read(key: 'access_token'), 'new-access-token');
      expect(await secureStorage.read(key: 'refresh_token'), 'refresh-token');
    });
  });
}
