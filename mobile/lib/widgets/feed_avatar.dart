import 'package:flutter/material.dart';

import '../utils/media_url.dart';
import 'sticker_pop.dart';

class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String id;
  final Color background;
  final Color foreground;
  final IconData icon;
}

// The ids are stored server-side: only the look of each option may change.
const List<AvatarOption> kAvatarOptions = [
  AvatarOption(
    id: 'ember',
    background: popCoral,
    foreground: popInk,
    icon: Icons.whatshot_outlined,
  ),
  AvatarOption(
    id: 'sea',
    background: popGreen,
    foreground: popInk,
    icon: Icons.waves_outlined,
  ),
  AvatarOption(
    id: 'citrus',
    background: popYellow,
    foreground: popInk,
    icon: Icons.emoji_food_beverage_outlined,
  ),
  AvatarOption(
    id: 'berry',
    background: Color(0xFFFFA6C9),
    foreground: popInk,
    icon: Icons.favorite_border,
  ),
  AvatarOption(
    id: 'noon',
    background: Color(0xFF7CC8FF),
    foreground: popInk,
    icon: Icons.sports_tennis_outlined,
  ),
  AvatarOption(
    id: 'terra',
    background: popPurple,
    foreground: Colors.white,
    icon: Icons.terrain_outlined,
  ),
];

class FeedAvatar extends StatelessWidget {
  const FeedAvatar({
    super.key,
    required this.username,
    this.avatarUrl,
    this.avatarKey,
    this.size = 44,
  });

  final String username;
  final String? avatarUrl;
  final String? avatarKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveMediaUrl(avatarUrl);
    final fallback = _FallbackAvatar(
      username: username,
      avatarKey: avatarKey,
      size: size,
    );

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: popBg),
      // Drawn over the picture so photos get the same ink outline.
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: popInk, width: size >= 40 ? popStroke : 2),
      ),
      child: ClipOval(
        child: resolvedUrl == null || resolvedUrl.isEmpty
            ? fallback
            : Image.network(
                resolvedUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({
    required this.username,
    required this.avatarKey,
    required this.size,
  });

  final String username;
  final String? avatarKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final option = _resolveAvatarOption(username, avatarKey);
    // Modification ici : utilisation de ?.isNotEmpty == true
    final isBaseAvatar = avatarKey?.isNotEmpty == true;
    final label = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: option.background,
      child: isBaseAvatar
          ? Icon(option.icon, color: option.foreground, size: size * 0.5)
          : Text(
              label,
              style: popTitle(
                fontSize: size * 0.42,
                color: option.foreground,
              ),
            ),
    );
  }

  AvatarOption _resolveAvatarOption(String username, String? avatarKey) {
    // Modification ici aussi pour harmoniser et éviter le même problème
    if (avatarKey?.isNotEmpty == true) {
      return kAvatarOptions.firstWhere(
        (option) => option.id == avatarKey,
        orElse: () => kAvatarOptions.first,
      );
    }

    final avatarIndex = _hashString(username) % kAvatarOptions.length;
    return kAvatarOptions[avatarIndex];
  }

  int _hashString(String value) {
    if (value.isEmpty) return 0;
    var hash = 0;
    for (final code in value.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }
}