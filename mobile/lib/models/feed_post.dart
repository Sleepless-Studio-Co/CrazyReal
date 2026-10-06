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

class FeedReaction {
  const FeedReaction({
    required this.emoji,
    required this.count,
    required this.reactedByMe,
  });

  final String emoji;
  final int count;
  final bool reactedByMe;

  factory FeedReaction.fromJson(Map<String, dynamic> json) {
    return FeedReaction(
      emoji: json['emoji']?.toString() ?? '',
      count: json['count'] is int ? json['count'] as int : 0,
      reactedByMe: json['reactedByMe'] == true,
    );
  }
}

class AvailableChallenge {
  const AvailableChallenge({
    required this.id,
    required this.title,
    required this.isGlobal,
    this.groupName,
  });

  final int id;
  final String title;
  final bool isGlobal;
  final String? groupName;

  factory AvailableChallenge.fromJson(Map<String, dynamic> json) {
    final group = json['group'];
    return AvailableChallenge(
      id: json['id'] as int,
      title: json['title']?.toString() ?? '',
      isGlobal: group == null,
      groupName: group is Map ? group['name']?.toString() : null,
    );
  }

  String label(String globalLabel, String friendLabel) {
    final scope = isGlobal ? globalLabel : friendLabel;
    final prefix = groupName == null ? scope : '$scope · $groupName';
    return '$prefix · $title';
  }
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.photoUrl,
    required this.user,
    this.createdAt,
    this.challenge,
    this.upvoteCount = 0,
    this.hasUpvoted = false,
    this.reactions = const [],
  });

  final int id;
  final String photoUrl;
  final DateTime? createdAt;
  final FeedUser user;
  final FeedChallenge? challenge;
  final int upvoteCount;
  final bool hasUpvoted;
  final List<FeedReaction> reactions;

  FeedPost copyWith({
    int? upvoteCount,
    bool? hasUpvoted,
  }) {
    return FeedPost(
      id: id,
      photoUrl: photoUrl,
      createdAt: createdAt,
      user: user,
      challenge: challenge,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      hasUpvoted: hasUpvoted ?? this.hasUpvoted,
      reactions: reactions,
    );
  }

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
      upvoteCount: json['upvoteCount'] is int ? json['upvoteCount'] as int : 0,
      hasUpvoted: json['hasUpvoted'] == true,
      reactions: (json['reactions'] is List)
          ? (json['reactions'] as List)
              .whereType<Map>()
              .map((item) => FeedReaction.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
    );
  }

  static List<FeedPost> listFromJson(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((item) => FeedPost.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static bool sameVoteState(List<FeedPost> a, List<FeedPost> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].upvoteCount != b[i].upvoteCount ||
          a[i].hasUpvoted != b[i].hasUpvoted) {
        return false;
      }
      if (a[i].reactions.length != b[i].reactions.length ||
          a[i].reactions.asMap().entries.any((entry) {
            final other = b[i].reactions[entry.key];
            final reaction = entry.value;
            return reaction.emoji != other.emoji ||
                reaction.count != other.count ||
                reaction.reactedByMe != other.reactedByMe;
          })) {
        return false;
      }
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
