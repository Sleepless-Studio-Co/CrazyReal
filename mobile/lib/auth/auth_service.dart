import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

  /// Fetches the current profile from the API and refreshes the cached user.
  /// Returns null when unauthenticated.
  Future<Map<String, dynamic>?> fetchProfile() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        return null;
      }

      if (response.statusCode != 200) {
        throw _buildHttpException('Failed to load profile', response);
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
      final response = await http.post(
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
        throw _buildHttpException('Could not resend verification email', response);
      }
    } on SocketException catch (e) {
      throw Exception('Network error: $e');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<void> _updateAccessToken(String accessToken) async {
    final refreshToken = await getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _saveTokens(accessToken, refreshToken);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
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
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unauthorized');
    }

    final payload = <String, String>{};
    if (email != null && email.isNotEmpty) {
      payload['email'] = email;
    }
    if (username != null && username.isNotEmpty) {
      payload['username'] = username;
    }

    if (payload.isEmpty) {
      throw Exception('No updates provided');
    }

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      }

      if (response.statusCode != 200) {
        throw _buildHttpException('Profile update failed', response);
      }

      final data = _decodeResponseMap(response.body);
      final accessToken = _extractToken(data, ['access_token', 'accessToken', 'token']);
      if (accessToken != null) {
        await _updateAccessToken(accessToken);
      }
      await _saveUserIfPresent(data['user']);
      return data;
    } on SocketException catch (e) {
      throw Exception('Network error: $e');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> updateAvatarKey(String avatarKey) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unauthorized');
    }

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/users/me/avatar'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'avatarKey': avatarKey}),
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      }

      if (response.statusCode != 200) {
        throw _buildHttpException('Avatar update failed', response);
      }

      final data = _decodeResponseMap(response.body);
      await _saveUserIfPresent(data['user']);
      return data;
    } on SocketException catch (e) {
      throw Exception('Network error: $e');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> updatePrivacy(bool isPrivate) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unauthorized');
    }

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/users/me/privacy'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isPrivate': isPrivate}),
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      }

      if (response.statusCode != 200) {
        throw _buildHttpException('Privacy update failed', response);
      }

      final data = _decodeResponseMap(response.body);
      await _saveUserIfPresent(data['user']);
      return data;
    } on SocketException catch (e) {
      throw Exception('Network error: $e');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> uploadAvatarImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unauthorized');
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/users/me/avatar'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw _buildHttpException('Avatar upload failed', response);
      }

      final data = _decodeResponseMap(response.body);
      await _saveUserIfPresent(data['user']);
      return data;
    } on SocketException catch (e) {
      throw Exception('Network error: $e');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> deleteAccount() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unauthorized');
    }
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 401) throw Exception('Unauthorized');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw _buildHttpException('Delete account failed', response);
      }
      await _clearTokens();
    } on SocketException catch (e) {
      throw Exception('Network error: $e');
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
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
