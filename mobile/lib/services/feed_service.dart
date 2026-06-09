import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';
import '../models/feed_post.dart';
import '../utils/media_url.dart';

enum FeedFetchStatus { success, unauthorized, error }

class FeedFetchResult {
  const FeedFetchResult({
    required this.status,
    this.posts = const [],
    this.errorMessage,
  });

  final FeedFetchStatus status;
  final List<FeedPost> posts;
  final String? errorMessage;
}

class FeedService {
  final AuthService _authService = AuthService();
  final String _baseUrl = apiBaseUrl;

  Future<String?> _tokenOrNull() => _authService.getAccessToken();

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<FeedFetchResult> fetchPosts() async {
    try {
      final token = await _tokenOrNull();
      if (token == null) {
        return const FeedFetchResult(status: FeedFetchStatus.unauthorized);
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/posts'),
        headers: _authHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FeedFetchResult(
          status: FeedFetchStatus.success,
          posts: FeedPost.listFromJson(data),
        );
      }

      if (response.statusCode == 401) {
        return const FeedFetchResult(status: FeedFetchStatus.unauthorized);
      }

      return FeedFetchResult(
        status: FeedFetchStatus.error,
        errorMessage: 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      return FeedFetchResult(
        status: FeedFetchStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<FeedChallengeSummary?> fetchCurrentChallenge() async {
    try {
      final token = await _tokenOrNull();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/challenge/current'),
        headers: _authHeaders(token),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      return FeedChallengeSummary.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
