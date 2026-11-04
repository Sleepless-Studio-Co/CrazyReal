import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';
import '../models/feed_post.dart';
import '../models/user_profile.dart';
import '../utils/media_url.dart';
import 'api_exception.dart';

class UserPostsPage {
  const UserPostsPage({required this.items, this.nextCursor});

  final List<FeedPost> items;
  final int? nextCursor;
}

class UserService {
  final AuthService _authService = AuthService();

  Future<UserProfile> fetchProfile(int userId) async {
    final data = await _get('/users/$userId');
    return UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<UserPostsPage> fetchProfilePosts(
    int userId, {
    int limit = 30,
    int? cursor,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (cursor != null) query['cursor'] = '$cursor';
    final path =
        '/users/$userId/posts?${query.entries.map((entry) => '${entry.key}=${entry.value}').join('&')}';
    final data = await _get(path);
    if (data is! Map) {
      return const UserPostsPage(items: []);
    }

    final items = data['items'];
    return UserPostsPage(
      items: items is List ? FeedPost.listFromJson(items) : const [],
      nextCursor: data['nextCursor'] is int ? data['nextCursor'] as int : null,
    );
  }

  Future<dynamic> _get(String path) async {
    final token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw UnauthorizedException();
    }

    http.Response response;
    try {
      response = await http.get(
        Uri.parse('$apiBaseUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    } on SocketException catch (e) {
      throw ApiException('Network error: $e');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw buildApiException(response);
    }

    if (response.body.isEmpty) return <String, dynamic>{};
    return jsonDecode(response.body);
  }
}
