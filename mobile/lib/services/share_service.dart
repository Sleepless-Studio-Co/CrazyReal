import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../auth/auth_service.dart';
import '../models/feed_post.dart';
import '../utils/media_url.dart';
import 'api_exception.dart';

class ShareService {
  final AuthService _authService = AuthService();

  Future<String> createShareLink(int postId) async {
    final token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) throw UnauthorizedException();

    final response = await http.post(
      Uri.parse('$apiBaseUrl/shares/posts/$postId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw buildApiException(response);
    }

    final data = jsonDecode(response.body);
    if (data is! Map || data['token'] is! String) {
      throw ApiException('Le lien de partage n’a pas pu être créé.');
    }

    final base = dotenvShareBaseUrl;
    return '$base/${Uri.encodeComponent(data['token'] as String)}';
  }

  Future<List<FeedPost>> fetchGuestFeed(String token) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/shares/${Uri.encodeComponent(token)}/feed'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw buildApiException(response);
    }
    return FeedPost.listFromJson(jsonDecode(response.body));
  }
}

String get dotenvShareBaseUrl {
  final configured = dotenv.env['SHARE_BASE_URL'];
  final base = configured == null || configured.isEmpty
      ? 'crazyreal://share'
      : configured;
  return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
}
