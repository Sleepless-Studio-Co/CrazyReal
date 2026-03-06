import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user';

  final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw _buildHttpException('Login failed', response);
      }

      final data = _decodeResponseMap(response.body);
      final accessToken = _extractToken(data, ['access_token', 'accessToken', 'token']);
      final refreshToken = _extractToken(data, ['refresh_token', 'refreshToken']);

      if (accessToken == null || refreshToken == null) {
        throw Exception('Login response missing auth tokens');
      }

      await _saveTokens(accessToken, refreshToken);
      await _saveUserIfPresent(data['user']);
      return data;
    } on SocketException catch (e) {
      throw Exception('Network error: $e');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>?> register(String email, String password, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'username': username}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw _buildHttpException('Registration failed', response);
      }

      final data = _decodeResponseMap(response.body);
      final accessToken = _extractToken(data, ['access_token', 'accessToken', 'token']);
      final refreshToken = _extractToken(data, ['refresh_token', 'refreshToken']);

      if (accessToken == null || refreshToken == null) {
        throw Exception('Registration response missing auth tokens');
      }

      await _saveTokens(accessToken, refreshToken);
      await _saveUserIfPresent(data['user']);
      return data;
    } on SocketException catch (e) {
      throw Exception('Network error: $e');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
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

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
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
    throw Exception('Unexpected response format');
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

  Exception _buildHttpException(String fallbackMessage, http.Response response) {
    try {
      final error = jsonDecode(response.body);
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) {
          return Exception(message);
        }
        if (message is List && message.isNotEmpty) {
          return Exception(message.join(', '));
        }
      }
    } catch (_) {
      // Keep fallback error below when response is not JSON.
    }

    return Exception('$fallbackMessage (status ${response.statusCode})');
  }
}
