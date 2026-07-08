import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth/auth_service.dart';
import 'api_exception.dart';

class FriendService {
  final String baseUrl = '${dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000'}/friends';
  final AuthService _authService = AuthService();

  Future<String> _getToken() async {
    final token = await _authService.getAccessToken();
    return token ?? '';
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<void> sendRequest(String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/request/$username'),
      headers: await _headers(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw buildApiException(response);
    }
  }

  Future<void> acceptRequest(int requestId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/accept/$requestId'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw buildApiException(response);
    }
  }

  Future<void> rejectRequest(int requestId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/reject/$requestId'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw buildApiException(response);
    }
  }

  Future<void> blockUser(String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/block/$username'),
      headers: await _headers(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw buildApiException(response);
    }
  }

  Future<List<dynamic>> searchUsers(String query) async {
    final root = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
    final response = await http.get(
      Uri.parse('$root/users/search?q=${Uri.encodeQueryComponent(query)}'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw buildApiException(response);
  }

  Future<List<dynamic>> getFriends() async {
    final response = await http.get(Uri.parse(baseUrl), headers: await _headers());

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw buildApiException(response);
  }

  Future<List<dynamic>> getPendingRequests() async {
    final response = await http.get(Uri.parse('$baseUrl/requests'), headers: await _headers());

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw buildApiException(response);
  }
}
