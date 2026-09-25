import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_exception.dart';

class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user';

  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  AuthService({http.Client? client, FlutterSecureStorage? secureStorage})
      : _client = client ?? http.Client(),
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  String get baseUrl {
    try {
      return dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
    } catch (_) {
      return 'http://localhost:3000';
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final response = await _unauthedPost('/auth/login', {
      'email': email,
      'password': password,
    });

    final data = _decodeResponseMap(response.body);
    await _persistSession(data);
    return data;
  }

  Future<Map<String, dynamic>?> register(
    String email,
    String password,
    String username,
  ) async {
    final response = await _unauthedPost('/auth/register', {
      'email': email,
      'password': password,
      'username': username,
    });

    final data = _decodeResponseMap(response.body);
    await _persistSession(data);
    return data;
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    final accessToken = _extractToken(data, ['access_token', 'accessToken', 'token']);
    final refreshToken = _extractToken(data, ['refresh_token', 'refreshToken']);
    if (accessToken == null || refreshToken == null) {
      throw ApiException('Auth response missing tokens');
    }
    await _saveTokens(accessToken, refreshToken);
    await _saveUserIfPresent(data['user']);
  }

  Future<void> logout() async {
    final refreshToken = await getRefreshToken();
    final accessToken = await getAccessToken();
    if (refreshToken != null) {
      try {
        await _client.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'refresh_token': refreshToken}),
        );
      } catch (e) {
        // Ignore logout errors
      }
    }
    await _clearTokens();
  }

  Future<String?> getAccessToken({bool refreshIfNeeded = false}) async {
    final currentToken = await _secureStorage.read(key: _accessTokenKey);
    if (!refreshIfNeeded || (currentToken != null && currentToken.isNotEmpty)) {
      return currentToken;
    }

    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      return currentToken;
    }

    return _refreshAccessToken(refreshToken);
  }

  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return jsonDecode(userJson);
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    final restored = await restoreSession();
    if (restored) {
      return true;
    }

    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<bool> restoreSession() async {
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final token = await _refreshAccessToken(refreshToken);
    if (token == null || token.isEmpty) {
      await _clearTokens();
      return false;
    }

    return true;
  }

  /// Fetches the current profile from the API and refreshes the cached user.
  /// Returns null when unauthenticated.
  Future<Map<String, dynamic>?> fetchProfile() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        return null;
      }

      if (response.statusCode != 200) {
        throw buildApiException(response);
      }

      final data = _decodeResponseMap(response.body);
      await _saveUser(data);
      return data;
    } on SocketException catch (e) {
      throw Exception('Network error: $e');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Asks the backend to resend the email-verification message.
  Future<void> resendVerificationEmail() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unauthorized');
    }

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/resend-verification'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw buildApiException(response);
      }
    } on SocketException catch (e) {
      throw Exception('Network error: $e');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> _updateAccessToken(String accessToken) async {
    final refreshToken = await getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _saveTokens(accessToken, refreshToken);
      return;
    }

    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<void> _saveUserIfPresent(dynamic user) async {
    if (user is Map<String, dynamic>) {
      await _saveUser(user);
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? email,
    String? username,
  }) async {
    final payload = <String, dynamic>{};
    if (email != null && email.isNotEmpty) {
      payload['email'] = email;
    }
    if (username != null && username.isNotEmpty) {
      payload['username'] = username;
    }

    if (payload.isEmpty) {
      throw ApiException('No updates provided');
    }

    final data = await _authedJson('PATCH', '/auth/me', body: payload);
    final accessToken = _extractToken(data, ['access_token', 'accessToken', 'token']);
    if (accessToken != null) {
      await _updateAccessToken(accessToken);
    }
    await _saveUserIfPresent(data['user']);
    return data;
  }

  Future<Map<String, dynamic>> updateAvatarKey(String avatarKey) async {
    final data = await _authedJson(
      'PATCH',
      '/users/me/avatar',
      body: {'avatarKey': avatarKey},
    );
    await _saveUserIfPresent(data['user']);
    return data;
  }

  Future<Map<String, dynamic>> updatePrivacy(bool isPrivate) async {
    final data = await _authedJson(
      'PATCH',
      '/users/me/privacy',
      body: {'isPrivate': isPrivate},
    );
    await _saveUserIfPresent(data['user']);
    return data;
  }

  Future<Map<String, dynamic>> uploadAvatarImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      throw UnauthorizedException();
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/users/me/avatar'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw buildApiException(response);
      }

      final data = _decodeResponseMap(response.body);
      await _saveUserIfPresent(data['user']);
      return data;
    } on SocketException catch (e) {
      throw ApiException('Network error: $e');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  Future<void> deleteAccount() async {
    await _authedJson('DELETE', '/users/me');
    await _clearTokens();
  }

  // ─── Shared request helpers ────────────────────────────────────────────────

  /// Authenticated JSON request. Throws [UnauthorizedException] when no token
  /// is stored or the server replies 401, and [ApiException] for other errors.
  Future<Map<String, dynamic>> _authedJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      throw UnauthorizedException();
    }

    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);

    http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = await _client.post(uri, headers: headers, body: encodedBody);
          break;
        case 'PATCH':
          response = await _client.patch(uri, headers: headers, body: encodedBody);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers, body: encodedBody);
          break;
        default:
          response = await _client.get(uri, headers: headers);
      }
    } on SocketException catch (e) {
      throw ApiException('Network error: $e');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: $e');
    }

    // buildApiException maps 401 → UnauthorizedException.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw buildApiException(response);
    }

    if (response.body.isEmpty) return <String, dynamic>{};
    return _decodeResponseMap(response.body);
  }

  Future<http.Response> _unauthedPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } on SocketException catch (e) {
      throw ApiException('Network error: $e');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw buildApiException(response);
    }
    return response;
  }

  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  Future<String?> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return null;
      }

      final data = _decodeResponseMap(response.body);
      final accessToken = _extractToken(data, ['access_token', 'accessToken', 'token']);
      if (accessToken == null || accessToken.isEmpty) {
        return null;
      }

      await _saveTokens(accessToken, refreshToken);
      return accessToken;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _decodeResponseMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException('Unexpected response format');
  }

  String? _extractToken(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
