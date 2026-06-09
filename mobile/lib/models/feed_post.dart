class FeedUser {
  const FeedUser({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.avatarKey,
  });

  final int id;
  final String username;
  final String? avatarUrl;
  final String? avatarKey;

  factory FeedUser.fromJson(Map<String, dynamic> json) {
    return FeedUser(
      id: json['id'] as int,
      username: json['username']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      avatarKey: json['avatarKey']?.toString(),
    );
  }
}

class FeedChallenge {
  const FeedChallenge({
    required this.id,
    required this.title,
    required this.type,
  });

  final int id;
  final String title;
  final String type;

  factory FeedChallenge.fromJson(Map<String, dynamic> json) {
    return FeedChallenge(
      id: json['id'] as int,
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.photoUrl,
    required this.user,
    this.createdAt,
    this.challenge,
  });

  final int id;
  final String photoUrl;
  final DateTime? createdAt;
  final FeedUser user;
  final FeedChallenge? challenge;

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt);
    }

    final userJson = json['user'];
    final challengeJson = json['challenge'];

    return FeedPost(
      id: json['id'] as int,
      photoUrl: json['photoUrl']?.toString() ?? '',
      createdAt: createdAt,
      user: userJson is Map<String, dynamic>
          ? FeedUser.fromJson(userJson)
          : const FeedUser(id: 0, username: ''),
      challenge: challengeJson is Map<String, dynamic>
          ? FeedChallenge.fromJson(challengeJson)
          : null,
    );
  }

  static List<FeedPost> listFromJson(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((item) => FeedPost.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static bool sameIds(List<FeedPost> a, List<FeedPost> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}

class FeedChallengeSummary {
  const FeedChallengeSummary({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  factory FeedChallengeSummary.fromJson(Map<String, dynamic> json) {
    return FeedChallengeSummary(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}
