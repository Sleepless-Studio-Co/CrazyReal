import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';
import '../models/feed_post.dart';
import '../utils/media_url.dart';
import 'api_exception.dart';

class FeedService {
  final AuthService _authService = AuthService();
  final String _baseUrl = apiBaseUrl;

  /// Throws [UnauthorizedException] when the session is invalid and
  /// [ApiException] for other failures.
  Future<List<FeedPost>> fetchPosts() async {
    final data = await _authedRequest('GET', '/posts');
    return FeedPost.listFromJson(data);
  }

  Future<FeedChallengeSummary?> fetchCurrentChallenge() async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/challenge/current'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      return FeedChallengeSummary.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<FeedPost> upvotePost(int postId) => _vote(postId, remove: false);

  Future<FeedPost> removeUpvote(int postId) => _vote(postId, remove: true);

  Future<FeedPost> _vote(int postId, {required bool remove}) async {
    final data = await _authedRequest(
      remove ? 'DELETE' : 'POST',
      '/posts/$postId/upvote',
    );
    return FeedPost.fromJson(data as Map<String, dynamic>);
  }

  Future<dynamic> _authedRequest(String method, String path) async {
    final token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw UnauthorizedException();
    }

    final uri = Uri.parse('$_baseUrl$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = await http.post(uri, headers: headers);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
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
    return jsonDecode(response.body);
  }
}
