import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'feed_avatar.dart';
import 'paper.dart';

/// Shared top section of a profile.
///
/// The public profile and the account tab render the exact same header so the
/// user always recognises their own profile when they open it from a post.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.username,
    required this.isPrivate,
    this.avatarUrl,
    this.avatarKey,
    this.avatarOverride,
    this.friendCount,
    this.challengeCount,
    this.onAvatarTap,
    this.avatarLoading = false,
    this.action,
  });

  final String username;
  final bool isPrivate;
  final String? avatarUrl;
  final String? avatarKey;

  /// Used to preview a freshly picked image before the upload finishes.
  final Widget? avatarOverride;
  final int? friendCount;
  final int? challengeCount;

  /// When set, the avatar gets a camera badge and becomes tappable.
  final VoidCallback? onAvatarTap;
  final bool avatarLoading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.paper;

    Widget avatarContent = avatarOverride ??
        FeedAvatar(
          username: username,
          avatarUrl: avatarUrl,
          avatarKey: avatarKey,
          size: 88,
        );

    Widget avatar = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [palette.accent, const Color(0xFFE9B384)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(shape: BoxShape.circle, color: palette.bg),
        child: SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipOval(child: avatarContent),
              if (avatarLoading)
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (onAvatarTap != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: palette.ink,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.bg, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: palette.bg,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (onAvatarTap != null) {
      avatar = Semantics(
        button: true,
        label: l10n.profilePhoto,
        child: GestureDetector(onTap: onAvatarTap, child: avatar),
      );
    }

    final showStats = friendCount != null || challengeCount != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        style: paperTitle(context, fontSize: 24),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPrivate) ...[
                      const SizedBox(width: 6),
                      Semantics(
                        label: l10n.privateAccount,
                        child: Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                if (showStats) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (challengeCount != null) ...[
                        _Stat(
                          value: challengeCount!,
                          label: l10n.profilePostsCount(challengeCount!),
                        ),
                        if (friendCount != null) const SizedBox(width: 10),
                      ],
                      if (friendCount != null)
                        _Stat(
                          value: friendCount!,
                          label: l10n.profileFriendsCount(friendCount!),
                        ),
                    ],
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 12),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.paper.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.paper.border),
        ),
        child: Column(
          children: [
            Text('$value', style: paperValue(context, fontSize: 18)),
            Text(label, style: paperMuted(context, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
