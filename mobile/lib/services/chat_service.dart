import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../utils/media_url.dart';
import 'api_exception.dart';

class ChatService {
  final String baseUrl = '$apiBaseUrl/chat';
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

  Future<List<dynamic>> getMessages(int conversationId, {int limit = 30, int? cursor, int? after}) async {
    final cursorParam = cursor != null ? '&cursor=$cursor' : '';
    final afterParam = after != null ? '&after=$after' : '';
    final response = await http.get(
      Uri.parse('$baseUrl/$conversationId/messages?limit=$limit$cursorParam$afterParam'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw buildApiException(response);
  }

  Future<List<dynamic>> getGroupChallenges(int conversationId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$conversationId/challenges'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw buildApiException(response);
  }

  Future<Map<String, dynamic>> createGroupChallenge(
    int conversationId, {
    required String title,
    required String description,
    required DateTime endsAt,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$conversationId/challenges'),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        'description': description,
        'endsAt': endsAt.toUtc().toIso8601String(),
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw buildApiException(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMessage(int conversationId, String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$conversationId/messages'),
      headers: await _headers(),
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw buildApiException(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
