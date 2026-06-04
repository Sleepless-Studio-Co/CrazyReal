import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/media_url.dart';

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

const List<AvatarOption> kAvatarOptions = [
  AvatarOption(
    id: 'ember',
    background: Color(0xFFE9B384),
    foreground: Color(0xFF3C2A21),
    icon: Icons.whatshot_outlined,
  ),
  AvatarOption(
    id: 'sea',
    background: Color(0xFF9FC0B9),
    foreground: Color(0xFF1E3D3A),
    icon: Icons.waves_outlined,
  ),
  AvatarOption(
    id: 'citrus',
    background: Color(0xFFF7E27C),
    foreground: Color(0xFF5E4B0A),
    icon: Icons.emoji_food_beverage_outlined,
  ),
  AvatarOption(
    id: 'berry',
    background: Color(0xFFD4A5A5),
    foreground: Color(0xFF4D2020),
    icon: Icons.favorite_border,
  ),
  AvatarOption(
    id: 'noon',
    background: Color(0xFFB1C5E5),
    foreground: Color(0xFF1F2F4A),
    icon: Icons.sports_tennis_outlined,
  ),
  AvatarOption(
    id: 'terra',
    background: Color(0xFFCBB39B),
    foreground: Color(0xFF4E3722),
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
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFEEDCC5),
        ),
        child: ClipOval(
          child: Image.network(
            resolvedUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _FallbackAvatar(
                username: username,
                avatarKey: avatarKey,
                size: size,
              );
            },
          ),
        ),
      );
    }

    return _FallbackAvatar(
      username: username,
      avatarKey: avatarKey,
      size: size,
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
              style: GoogleFonts.karla(
                color: option.foreground,
                fontSize: size * 0.44,
                fontWeight: FontWeight.w700,
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