import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_exception.dart';
import '../utils/media_url.dart';

class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user';

  final String baseUrl = apiBaseUrl;

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
    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
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
        await http.post(
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

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
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
    final token = await getAccessToken();
    return token != null;
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
    final accessToken = data['access_token'];
    if (accessToken is String && accessToken.isNotEmpty) {
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
          response = await http.post(uri, headers: headers, body: encodedBody);
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: encodedBody);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers, body: encodedBody);
          break;
        default:
          response = await http.get(uri, headers: headers);
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
      response = await http.post(
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

  // ─── Token / user persistence ──────────────────────────────────────────────

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<void> _updateAccessToken(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
  }

  Future<void> _saveUserIfPresent(dynamic user) async {
    if (user is Map<String, dynamic>) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    }
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
  }

  Map<String, dynamic> _decodeResponseMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException('Unexpected response format');
  }
}
