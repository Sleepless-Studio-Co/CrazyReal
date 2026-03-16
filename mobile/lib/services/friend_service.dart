import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth/auth_service.dart';

class FriendService {
  final String baseUrl = '${dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000'}/friends';
  final AuthService _authService = AuthService();

  Future<String> _getToken() async {
    final token = await _authService.getAccessToken();
    return token ?? '';
  }

  // 1. Envoyer une demande d'ami via le pseudo
  Future<bool> sendRequest(String username) async { // <-- Changement : String au lieu de int
    try {
      final token = await _getToken();
      final response = await http.post(
        // On passe directement le pseudo dans l'URL
        Uri.parse('$baseUrl/request/$username'), 
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Erreur sendRequest: $e');
      return false;
    }
  }

  Future<bool> acceptRequest(int requestId) async {
    try {
      final token = await _getToken();
      final response = await http.patch(
        Uri.parse('$baseUrl/accept/$requestId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Erreur acceptRequest: $e');
      return false;
    }
  }

  Future<List<dynamic>> getFriends() async {
    try {
      final token = await _getToken();
      final response = await http.get(
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
      print('Erreur getFriends: $e');
      return [];
    }
  }

  // 4. Récupérer les demandes en attente
  Future<List<dynamic>> getPendingRequests() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        // On interroge la nouvelle route backend
        Uri.parse('$baseUrl/requests'), 
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
      print('Erreur getPendingRequests: $e');
      return [];
    }
  }
}