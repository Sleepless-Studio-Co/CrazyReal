import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'models/feed_post.dart';
import 'services/api_exception.dart';
import 'services/feed_service.dart';
import 'utils/media_url.dart';
import 'widgets/feed_avatar.dart';
import 'widgets/paper.dart';
import 'widgets/post_card.dart';

/// Public profile: avatar, counters and an Instagram-like grid of the
/// challenges the user completed. Tapping a tile opens the scrollable list.
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.userId});

  final int userId;

  static Future<void> open(BuildContext context, int userId) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)),
    );
  }

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final FeedService _feedService = FeedService();
  UserProfile? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _feedService.fetchUserProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profile = _profile;

    return Scaffold(
      backgroundColor: paperBg,
      appBar: paperAppBar(title: profile?.user.username ?? ''),
      body: profile == null
          ? (_error == null
              ? const Center(
                  child: CircularProgressIndicator(color: paperAccent),
                )
              : PaperEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: l10n.profileLoadError,
                  message: _error,
                  action: FilledButton.tonalIcon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.refresh),
                  ),
                ))
          : RefreshIndicator(
              onRefresh: _load,
              color: paperAccent,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _ProfileHeader(profile: profile)),
                  ..._buildContent(context, l10n, profile),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    UserProfile profile,
  ) {
    if (profile.isLocked || profile.posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
            child: Column(
              children: [
                Icon(
                  profile.isLocked
                      ? Icons.lock_outline
                      : Icons.photo_camera_outlined,
                  size: 56,
                  color: paperInkMuted.withValues(alpha: 0.75),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.isLocked
                      ? l10n.profilePrivateTitle
                      : l10n.profileNoPosts,
                  style: paperValue(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (profile.isLocked) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.profilePrivateMessage,
                    style: paperMuted(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            childAspectRatio: 4 / 5,
          ),
          itemCount: profile.posts.length,
          itemBuilder: (context, index) => _GridTile(
            post: profile.posts[index],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ProfilePostsPage(
                  username: profile.user.username,
                  posts: profile.posts,
                  initialIndex: index,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final postCount = profile.posts.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        children: [
          // Accent ring, the 2026 social-app way of framing a profile photo.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [paperAccent, Color(0xFFE9B384)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: paperBg,
              ),
              child: FeedAvatar(
                username: profile.user.username,
                avatarUrl: profile.user.avatarUrl,
                avatarKey: profile.user.avatarKey,
                size: 88,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.user.username,
                        style: paperTitle(fontSize: 24),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile.isPrivate) ...[
                      const SizedBox(width: 6),
                      Semantics(
                        label: l10n.privateAccount,
                        child: const Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: paperInkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!profile.isLocked) ...[
                      _Stat(
                        value: postCount,
                        label: l10n.profilePostsCount(postCount),
                      ),
                      const SizedBox(width: 10),
                    ],
                    _Stat(
                      value: profile.friendCount,
                      label: l10n.profileFriendsCount(profile.friendCount),
                    ),
                  ],
                ),
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
          color: paperCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: paperBorder),
        ),
        child: Column(
          children: [
            Text('$value', style: paperValue(fontSize: 18)),
            Text(label, style: paperMuted(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.post, required this.onTap});

  final FeedPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = resolveMediaUrl(post.photoUrl) ?? '';
    final title = post.challenge?.title ?? '';

    return Semantics(
      button: true,
      label: title,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: const Color(0xFFEEDCC5),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ponytail: videos show a placeholder, generate server-side
                // thumbnails if the grid needs real previews.
                if (post.isVideo)
                  const ColoredBox(color: Color(0xFF2A211C))
                else
                  Hero(
                    tag: 'post-photo-${post.id}',
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      cacheWidth: 400,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: paperInkMuted,
                      ),
                    ),
                  ),
                if (post.isVideo)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 20,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black45)],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width scrollable list of a profile's posts, opened on the tapped one.
class _ProfilePostsPage extends StatefulWidget {
  const _ProfilePostsPage({
    required this.username,
    required this.posts,
    required this.initialIndex,
  });

  final String username;
  // ponytail: shared with the grid page and mutated in place on upvote, so
  // reopening the list keeps the vote state without a refetch.
  final List<FeedPost> posts;
  final int initialIndex;

  @override
  State<_ProfilePostsPage> createState() => _ProfilePostsPageState();
}

class _ProfilePostsPageState extends State<_ProfilePostsPage> {
  final FeedService _feedService = FeedService();
  final Key _centerKey = UniqueKey();

  Future<void> _toggleUpvote(int index) async {
    final posts = widget.posts;
    final original = posts[index];
    final wasUpvoted = original.hasUpvoted;

    setState(() {
      posts[index] = original.copyWith(
        hasUpvoted: !wasUpvoted,
        upvoteCount: original.upvoteCount + (wasUpvoted ? -1 : 1),
      );
    });

    try {
      final post = wasUpvoted
          ? await _feedService.removeUpvote(original.id)
          : await _feedService.upvotePost(original.id);
      if (!mounted) return;
      setState(() => posts[index] = post);
    } catch (_) {
      if (!mounted) return;
      setState(() => posts[index] = original);
    }
  }

  Widget _card(AppLocalizations l10n, int index) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: PostCard(
        post: widget.posts[index],
        unknownUserLabel: l10n.unknownUser,
        onUpvote: () => _toggleUpvote(index),
        linkAvatarToProfile: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final start = widget.initialIndex;

    return Scaffold(
      backgroundColor: paperBg,
      appBar: paperAppBar(
        title: l10n.profilePosts,
        subtitle: widget.username,
      ),
      // Two slivers around a `center` key: the list opens exactly on the
      // tapped post while staying lazily built in both directions.
      body: CustomScrollView(
        center: _centerKey,
        slivers: [
          SliverList.builder(
            itemCount: start,
            itemBuilder: (_, i) => _card(l10n, start - 1 - i),
          ),
          SliverPadding(
            key: _centerKey,
            padding: const EdgeInsets.only(bottom: 28),
            sliver: SliverList.builder(
              itemCount: widget.posts.length - start,
              itemBuilder: (_, i) => _card(l10n, start + i),
            ),
          ),
        ],
      ),
    );
  }
}
