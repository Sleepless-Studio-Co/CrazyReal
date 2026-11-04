import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'models/feed_post.dart';
import 'models/user_profile.dart';
import 'services/api_exception.dart';
import 'services/friend_service.dart';
import 'services/user_service.dart';
import 'utils/media_url.dart';
import 'widgets/feed_avatar.dart';
import 'widgets/full_screen_photo_page.dart';
import 'widgets/full_screen_video_page.dart';
import 'widgets/paper.dart';
import 'widgets/streak_card.dart';

/// Privacy-aware public profile. Shows the global-challenge streak and public
/// posts when the viewer is allowed to see them.
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.userId,
    this.onUnauthorized,
  });

  final int userId;
  final VoidCallback? onUnauthorized;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final UserService _userService = UserService();
  final FriendService _friendService = FriendService();

  UserProfile? _profile;
  List<FeedPost> _posts = [];
  bool _isLoading = true;
  bool _isLoadingPosts = false;
  bool _isSendingRequest = false;
  bool _requestSent = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final profile = await _userService.fetchProfile(widget.userId);
      if (!mounted) return;

      setState(() {
        _profile = profile;
        _isLoading = false;
      });

      if (profile.canViewContent) {
        await _loadPosts();
      }
    } on UnauthorizedException {
      if (!mounted) return;
      if (widget.onUnauthorized != null) {
        widget.onUnauthorized!();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context)!.error;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            e is ApiException ? e.message : AppLocalizations.of(context)!.error;
      });
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoadingPosts = true);
    try {
      final page = await _userService.fetchProfilePosts(widget.userId);
      if (!mounted) return;
      setState(() {
        _posts = page.items;
        _isLoadingPosts = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPosts = false);
      }
    }
  }

  Future<void> _sendRequest() async {
    final profile = _profile;
    if (profile == null || _isSendingRequest || _requestSent) return;

    setState(() => _isSendingRequest = true);
    try {
      await _friendService.sendRequest(profile.username);
      if (!mounted) return;
      setState(() => _requestSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.friendRequestSent(profile.username),
          ),
          backgroundColor: paperSuccess,
        ),
      );
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : AppLocalizations.of(context)!.error,
          ),
          backgroundColor: paperDanger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingRequest = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _profile?.username.isNotEmpty == true
        ? _profile!.username
        : l10n.profile;

    return Scaffold(
      backgroundColor: paperBg,
      appBar: paperAppBar(
        title: title,
        actions: [
          if (!_isLoading)
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: l10n.refresh,
            ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: paperAccent));
    }

    if (_errorMessage != null || _profile == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          _MessageCard(
            icon: Icons.cloud_off_outlined,
            title: l10n.error,
            message: _errorMessage ?? l10n.error,
            action: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.refresh),
              style: FilledButton.styleFrom(
                backgroundColor: paperAccentStrong,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    final profile = _profile!;

    return RefreshIndicator(
      onRefresh: _load,
      color: paperAccent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildHeader(profile, l10n),
          const SizedBox(height: 16),
          if (profile.canViewContent) ...[
            if (profile.streak != null) ...[
              StreakCard(streak: profile.streak!),
              const SizedBox(height: 12),
            ],
            _buildStats(profile, l10n),
            const SizedBox(height: 20),
            _buildPosts(l10n),
          ] else
            _MessageCard(
              icon: Icons.lock_outline,
              title: l10n.profileLockedTitle,
              message: l10n.profileLockedHint,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(UserProfile profile, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF2D9),
            Color(0xFFF0D0A8),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332E1B0F),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.75),
            ),
            child: FeedAvatar(
              username: profile.username,
              avatarUrl: profile.avatarUrl,
              avatarKey: profile.avatarKey,
              size: 88,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.username,
                  style: paperTitle(fontSize: 28),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _ProfileChip(
                      icon:
                          profile.isPrivate ? Icons.lock_outline : Icons.public,
                      label: profile.isPrivate
                          ? l10n.privateAccount
                          : l10n.publicAccount,
                    ),
                    if (profile.isSelf)
                      _ProfileChip(
                        icon: Icons.person_outline,
                        label: l10n.profileYou,
                      )
                    else if (profile.isFriend)
                      _ProfileChip(
                        icon: Icons.people_outline,
                        label: l10n.profileFriend,
                      ),
                  ],
                ),
                if (profile.createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.profileMemberSince('${profile.createdAt!.year}'),
                    style: paperMuted(fontSize: 12),
                  ),
                ],
                if (!profile.isSelf && !profile.isFriend) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed:
                        _isSendingRequest || _requestSent ? null : _sendRequest,
                    icon: Icon(
                      _requestSent ? Icons.check : Icons.person_add_alt_1,
                      size: 18,
                    ),
                    label: Text(
                      _requestSent ? l10n.requestSentShort : l10n.addFriend,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: paperAccentStrong,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(UserProfile profile, AppLocalizations l10n) {
    final stats = profile.stats;
    final posts = stats?.postsCount ?? 0;
    final challenges = stats?.challengesCount ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: paperCardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _ProfileStat(
              value: '$posts',
              label: l10n.profilePublications,
            ),
          ),
          Container(width: 1, height: 34, color: paperBorder),
          Expanded(
            child: _ProfileStat(
              value: '$challenges',
              label: l10n.profileChallenges,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosts(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.profilePublications,
                style: paperTitle(fontSize: 20),
              ),
            ),
            if (_isLoadingPosts)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: paperAccent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_posts.isEmpty && !_isLoadingPosts)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: paperCardDecoration(),
            child: Column(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  color: paperInkMuted,
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.profileNoPosts,
                  style: paperMuted(),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _posts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) => _PostTile(post: _posts[index]),
          ),
      ],
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final url = resolveMediaUrl(post.photoUrl) ?? '';
    final caption = post.challenge?.title;

    return GestureDetector(
      onTap: () {
        if (post.isVideo) {
          FullScreenVideoPage.open(
            context,
            videoUrl: url,
            caption: caption,
          );
        } else {
          FullScreenPhotoPage.open(
            context,
            imageUrl: url,
            caption: caption,
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: post.isVideo
            ? Container(
                color: const Color(0xFF2E1B0F),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: paperChip,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: paperAccent,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: paperChip,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: paperInkMuted,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: paperInkMuted),
          const SizedBox(width: 5),
          Text(label, style: paperLabel(fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: paperTitle(fontSize: 22)),
        const SizedBox(height: 2),
        Text(label, style: paperMuted(fontSize: 11.5)),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: paperCardDecoration(),
      child: Column(
        children: [
          Icon(icon, size: 34, color: paperAccentStrong),
          const SizedBox(height: 10),
          Text(
            title,
            style: paperValue(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: paperMuted(),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
