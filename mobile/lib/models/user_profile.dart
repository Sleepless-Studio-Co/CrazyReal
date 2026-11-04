class UserStreakCurrentEdition {
  const UserStreakCurrentEdition({
    required this.id,
    required this.title,
    required this.participated,
    this.startsAt,
    this.endsAt,
  });

  final int id;
  final String title;
  final bool participated;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory UserStreakCurrentEdition.fromJson(Map<String, dynamic> json) {
    return UserStreakCurrentEdition(
      id: json['id'] is int ? json['id'] as int : 0,
      title: json['title']?.toString() ?? '',
      participated: json['participated'] == true,
      startsAt: DateTime.tryParse(json['startsAt']?.toString() ?? ''),
      endsAt: DateTime.tryParse(json['endsAt']?.toString() ?? ''),
    );
  }
}

class UserStreak {
  const UserStreak({
    required this.current,
    required this.best,
    required this.status,
    required this.hasPostedInCurrentEdition,
    required this.participatedEditions,
    this.currentEdition,
  });

  final int current;
  final int best;
  final String status;
  final bool hasPostedInCurrentEdition;
  final int participatedEditions;
  final UserStreakCurrentEdition? currentEdition;

  bool get isActive => current > 0;
  bool get isAtRisk => status == 'at_risk';

  factory UserStreak.fromJson(Map<String, dynamic> json) {
    final editionJson = json['currentEdition'];
    return UserStreak(
      current: json['current'] is int ? json['current'] as int : 0,
      best: json['best'] is int ? json['best'] as int : 0,
      status: json['status']?.toString() ?? 'none',
      hasPostedInCurrentEdition: json['hasPostedInCurrentEdition'] == true,
      participatedEditions: json['participatedEditions'] is int
          ? json['participatedEditions'] as int
          : 0,
      currentEdition: editionJson is Map
          ? UserStreakCurrentEdition.fromJson(
              Map<String, dynamic>.from(editionJson),
            )
          : null,
    );
  }
}

class UserProfileStats {
  const UserProfileStats({
    required this.postsCount,
    required this.challengesCount,
  });

  final int postsCount;
  final int challengesCount;

  factory UserProfileStats.fromJson(Map<String, dynamic> json) {
    return UserProfileStats(
      postsCount: json['postsCount'] is int ? json['postsCount'] as int : 0,
      challengesCount:
          json['challengesCount'] is int ? json['challengesCount'] as int : 0,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.isPrivate,
    required this.isFriend,
    required this.isSelf,
    required this.canViewContent,
    this.avatarUrl,
    this.avatarKey,
    this.createdAt,
    this.streak,
    this.stats,
  });

  final int id;
  final String username;
  final String? avatarUrl;
  final String? avatarKey;
  final bool isPrivate;
  final bool isFriend;
  final bool isSelf;
  final bool canViewContent;
  final DateTime? createdAt;
  final UserStreak? streak;
  final UserProfileStats? stats;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final streakJson = json['streak'];
    final statsJson = json['stats'];
    final isPrivate = json['isPrivate'] == true;
    final isFriend = json['isFriend'] == true;
    final isSelf = json['isSelf'] == true;

    return UserProfile(
      id: json['id'] is int ? json['id'] as int : 0,
      username: json['username']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      avatarKey: json['avatarKey']?.toString(),
      isPrivate: isPrivate,
      isFriend: isFriend,
      isSelf: isSelf,
      canViewContent: json['canViewContent'] is bool
          ? json['canViewContent'] as bool
          : (isSelf || !isPrivate || isFriend),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      streak: streakJson is Map
          ? UserStreak.fromJson(Map<String, dynamic>.from(streakJson))
          : null,
      stats: statsJson is Map
          ? UserProfileStats.fromJson(Map<String, dynamic>.from(statsJson))
          : null,
    );
  }
}
