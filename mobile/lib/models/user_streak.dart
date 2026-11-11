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
