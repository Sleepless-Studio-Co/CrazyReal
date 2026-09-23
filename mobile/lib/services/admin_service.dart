import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';
import '../utils/media_url.dart';
import 'api_exception.dart';

/// Types de défi global, alignés sur l'enum `ChallengeType` du backend.
enum ChallengeType { weeklyA, weeklyB, special }

extension ChallengeTypeApi on ChallengeType {
  String get apiValue => switch (this) {
        ChallengeType.weeklyA => 'WEEKLY_A',
        ChallengeType.weeklyB => 'WEEKLY_B',
        ChallengeType.special => 'SPECIAL',
      };

  /// Durée d'activité dérivée du type, comme le calcule le backend.
  Duration get duration => this == ChallengeType.special
      ? const Duration(hours: 24)
      : const Duration(hours: 84);

  static ChallengeType fromApi(String? value) => switch (value) {
        'WEEKLY_B' => ChallengeType.weeklyB,
        'SPECIAL' => ChallengeType.special,
        _ => ChallengeType.weeklyA,
      };
}

/// Un défi global tel que renvoyé par `/admin/challenges`.
class AdminChallenge {
  const AdminChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    required this.isActive,
    required this.postCount,
  });

  final int id;
  final String title;
  final String description;
  final DateTime date;
  final ChallengeType type;
  final bool isActive;
  final int postCount;

  factory AdminChallenge.fromJson(Map<String, dynamic> json) {
    return AdminChallenge(
      id: json['id'] as int,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      type: ChallengeTypeApi.fromApi(json['type']?.toString()),
      isActive: json['isActive'] == true,
      postCount: (json['_count']?['posts'] as int?) ?? 0,
    );
  }

  DateTime get endsAt => date.add(type.duration);

  bool get isRunning {
    final now = DateTime.now();
    return isActive && !now.isBefore(date) && now.isBefore(endsAt);
  }

  bool get isUpcoming => isActive && DateTime.now().isBefore(date);
}

class AdminService {
  final String baseUrl = '$apiBaseUrl/admin';
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw UnauthorizedException();
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<List<AdminChallenge>> getChallenges() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/challenges'), headers: headers),
    );

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw ApiException('Unexpected response format');
    }
    return decoded
        .map((e) => AdminChallenge.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminChallenge> createChallenge({
    required String title,
    required String description,
    required DateTime date,
    required ChallengeType type,
    bool isActive = true,
  }) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/challenges'),
        headers: headers,
        body: jsonEncode({
          'title': title,
          'description': description,
          'date': date.toUtc().toIso8601String(),
          'type': type.apiValue,
          'isActive': isActive,
        }),
      ),
    );

    return AdminChallenge.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminChallenge> updateChallenge(
    int id, {
    String? title,
    String? description,
    DateTime? date,
    ChallengeType? type,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (date != null) 'date': date.toUtc().toIso8601String(),
      if (type != null) 'type': type.apiValue,
      if (isActive != null) 'isActive': isActive,
    };

    final response = await _send(
      (headers) => http.patch(
        Uri.parse('$baseUrl/challenges/$id'),
        headers: headers,
        body: jsonEncode(payload),
      ),
    );

    return AdminChallenge.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteChallenge(int id) async {
    await _send(
      (headers) =>
          http.delete(Uri.parse('$baseUrl/challenges/$id'), headers: headers),
    );
  }

  Future<int> importChallengesFromFile() async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/import-challenges'),
        headers: headers,
      ),
    );

    final decoded = jsonDecode(response.body);
    return decoded is Map && decoded['imported'] is int
        ? decoded['imported'] as int
        : 0;
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    final headers = await _headers();

    http.Response response;
    try {
      response = await request(headers);
    } on SocketException catch (e) {
      throw ApiException('Network error: $e');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: $e');
    }

    // buildApiException maps 401 → UnauthorizedException ; le 403 renvoyé par
    // l'AdminGuard remonte tel quel.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw buildApiException(response);
    }
    return response;
  }
}
