import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth/auth_service.dart';

class ChatService {
  final String baseUrl = '${dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000'}/chat';
  final AuthService _authService = AuthService();

  Future<String> _getToken() async {
    final token = await _authService.getAccessToken();
    return token ?? '';
  }

  // Créer un groupe
  Future<bool> createGroup(String name, List<int> memberIds) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/group'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'members': memberIds,
        }),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Erreur createGroup: $e');
      return false;
    }
  }

  // Récupérer la liste des conversations (groupes et privées)
  Future<List<dynamic>> getConversations() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        // Le baseUrl est déjà configuré sur '/chat', donc on l'appelle directement
        Uri.parse(baseUrl), 
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getConversations: $e');
      return [];
    }
  }

  // Récupérer l'historique des messages d'une conversation
  Future<List<dynamic>> getMessages(int conversationId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/$conversationId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Erreur getMessages: $e');
      return [];
    }
  }

  // Envoyer un nouveau message
  Future<bool> sendMessage(int conversationId, String content) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/$conversationId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': content}),
      );
      
      return response.statusCode == 201;
    } catch (e) {
      print('Erreur sendMessage: $e');
      return false;
    }
  }
}