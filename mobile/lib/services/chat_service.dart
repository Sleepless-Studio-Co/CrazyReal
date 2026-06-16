import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth/auth_service.dart';
import 'api_exception.dart';

class ChatService {
  final String baseUrl = '${dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000'}/chat';
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

  Future<void> createGroup(String name, List<int> memberIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/group'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'members': memberIds}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw buildApiException(response);
    }
  }

  Future<List<dynamic>> getConversations({int page = 1, int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl?page=$page&limit=$limit'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw buildApiException(response);
  }

  Future<void> leaveGroup(int conversationId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$conversationId/leave'),
      headers: await _headers(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw buildApiException(response);
    }
  }

  Future<void> removeMember(int conversationId, int memberId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$conversationId/members/$memberId'),
      headers: await _headers(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw buildApiException(response);
    }
  }

  Future<List<dynamic>> getMembers(int conversationId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$conversationId/members'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw buildApiException(response);
  }

  Future<void> promoteMember(int conversationId, int memberId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/$conversationId/members/$memberId/promote'),
      headers: await _headers(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw buildApiException(response);
    }
  }

  Future<void> demoteMember(int conversationId, int memberId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/$conversationId/members/$memberId/demote'),
      headers: await _headers(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw buildApiException(response);
    }
  }

  Future<List<dynamic>> getMessages(int conversationId, {int limit = 30, int? cursor}) async {
    final cursorParam = cursor != null ? '&cursor=$cursor' : '';
    final response = await http.get(
      Uri.parse('$baseUrl/$conversationId/messages?limit=$limit$cursorParam'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw buildApiException(response);
  }

  Future<void> sendMessage(int conversationId, String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$conversationId/messages'),
      headers: await _headers(),
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw buildApiException(response);
    }
  }
}
