import 'dart:async';

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'l10n/app_localizations.dart';
import 'models/feed_post.dart';
import 'services/api_exception.dart';
import 'services/feed_service.dart';
import 'utils/media_url.dart';
import 'utils/time_ago.dart';
import 'widgets/post_card.dart';
import 'widgets/post_card_skeleton.dart';
import 'widgets/sticker_pop.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onUnauthorized,
    this.onPublishTap,
  });

  final VoidCallback onUnauthorized;
  final VoidCallback? onPublishTap;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final FeedService _feedService = FeedService();

  List<FeedPost> _posts = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  FeedChallengeSummary? _currentChallenge;
  List<AvailableChallenge> _availableChallenges = [];
  int _selectedChallengeId = -1;
  bool _isActive = true;

  IO.Socket? _socket;
  Timer? _pollTimer;

  static const Duration _pollInterval = Duration(seconds: 25);

  @override
  void initState() {
    super.initState();
    _initSocket();
    refreshFeed(showLoading: true);
    _loadAvailableChallenges();
    _loadCurrentChallenge();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  void setActive(bool active) {
    _isActive = active;
    if (active) {
      refreshFeed(showLoading: false);
      _startPolling();
    } else {
      _pollTimer?.cancel();
    }
  }

  Future<void> refreshFeed({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (mounted) {
      setState(() => _isRefreshing = true);
    }

    try {
      final posts = await _feedService.fetchPostsForChallenge(
        _selectedChallengeId == -1 ? null : _selectedChallengeId,
      );
      if (!mounted) return;

      final shouldUpdate = !FeedPost.sameVoteState(_posts, posts);
      setState(() {
        if (shouldUpdate) {
          _posts = posts;
        }
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });

      // The API answers again: bring back the challenge card and filters if
      // they could not load at startup (server still booting, offline…).
      if (_currentChallenge == null) _loadCurrentChallenge();
      if (_availableChallenges.isEmpty) _loadAvailableChallenges();
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadAvailableChallenges() async {
    try {
      final challenges = await _feedService.fetchAvailableChallenges();
      if (!mounted) return;
      setState(() => _availableChallenges = challenges);
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized();
    } catch (_) {
      // The feed remains usable if the filter list cannot be loaded.
    }
  }

  void _selectChallenge(int id) {
    if (_selectedChallengeId == id) return;
    setState(() => _selectedChallengeId = id);
    refreshFeed(showLoading: true);
  }

  Future<void> _loadCurrentChallenge() async {
    final challenge = await _feedService.fetchCurrentChallenge();
    if (!mounted || challenge == null || challenge.title.isEmpty) return;

    setState(() => _currentChallenge = challenge);
  }

  /// End of the current challenge, as computed by the server for the list of
  /// available challenges.
  DateTime? get _currentChallengeEndsAt {
    final id = _currentChallenge?.id;
    if (id == null) return null;
    return _availableChallenges
        .where((challenge) => challenge.id == id)
        .firstOrNull
        ?.endsAt;
  }

  void _initSocket() {
    _socket = IO.io(
      '$apiBaseUrl/feed',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();
    _socket!.on('newPost', _handleNewPost);
  }

  void _handleNewPost(dynamic data) {
    if (!_isActive || !mounted) return;

    try {
      final post = FeedPost.fromJson(Map<String, dynamic>.from(data as Map));
      if (!_isPostVisibleForCurrentFilter(post)) return;
      if (_posts.any((existing) => existing.id == post.id)) return;

      setState(() {
        _posts = [post, ..._posts];
        _errorMessage = null;
      });
    } catch (_) {
      refreshFeed(showLoading: false);
    }
  }

  bool _isPostVisibleForCurrentFilter(FeedPost post) {
    final challengeId = post.challenge?.id;
    if (challengeId == null) return false;
    if (_selectedChallengeId != -1) {
      return challengeId == _selectedChallengeId;
    }

    final globalIds = _availableChallenges
        .where((challenge) => challenge.isGlobal)
        .take(2)
        .map((challenge) => challenge.id);
    final friendIds = _availableChallenges
        .where((challenge) => !challenge.isGlobal)
        .take(2)
        .map((challenge) => challenge.id);
    return {...globalIds, ...friendIds}.contains(challengeId);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (_isActive && mounted) {
        refreshFeed(showLoading: false);
      }
    });
  }

  Future<void> _toggleUpvote(int postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final original = _posts[index];
    final wasUpvoted = original.hasUpvoted;

    setState(() {
      _posts[index] = original.copyWith(
        hasUpvoted: !wasUpvoted,
        upvoteCount: original.upvoteCount + (wasUpvoted ? -1 : 1),
      );
    });

    try {
      final post = wasUpvoted
          ? await _feedService.removeUpvote(postId)
          : await _feedService.upvotePost(postId);
      if (!mounted) return;
      setState(() => _posts[index] = post);
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _posts[index] = original);
      widget.onUnauthorized();
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = original);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final challenge = _currentChallenge;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => refreshFeed(showLoading: false),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        const PopLogo(),
                        const Spacer(),
                        PopIconButton(
                          icon: Icons.refresh,
                          tooltip: l10n.feedRefresh,
                          busy: _isRefreshing,
                          onPressed: () => refreshFeed(showLoading: false),
                        ),
                      ],
                    ),
                    if (challenge != null) ...[
                      const SizedBox(height: 26),
                      _ChallengeHero(
                        challenge: challenge,
                        endsAt: _currentChallengeEndsAt,
                        onDoIt: widget.onPublishTap,
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              SliverToBoxAdapter(child: _buildChallengeFilter(l10n)),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              ..._buildFeed(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeFilter(AppLocalizations l10n) {
    final filters = <Widget>[
      PopChip(
        label: l10n.feedAllChallenges,
        selected: _selectedChallengeId == -1,
        onTap: () => _selectChallenge(-1),
      ),
      for (final challenge in _availableChallenges)
        PopChip(
          label: challenge.groupName == null
              ? challenge.title
              : '${challenge.groupName} · ${challenge.title}',
          icon: challenge.isGlobal ? Icons.public : Icons.groups_outlined,
          semanticLabel: challenge.label(
              l10n.feedGlobalChallenge, l10n.feedFriendChallenge),
          selected: _selectedChallengeId == challenge.id,
          onTap: () => _selectChallenge(challenge.id),
        ),
    ];

    // Sized by its chips so large text never overflows; the bottom padding
    // keeps the selected chip's shadow inside the clipped scroll view.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < filters.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            filters[i],
          ],
        ],
      ),
    );
  }

  List<Widget> _buildFeed(AppLocalizations l10n) {
    const listPadding = EdgeInsets.fromLTRB(16, 4, 16, 28);

    if (_isLoading) {
      return [
        SliverPadding(
          padding: listPadding,
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: 20),
            itemBuilder: (_, __) => const PostCardSkeleton(),
          ),
        ),
      ];
    }

    if (_errorMessage != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PopEmptyState(
            scrollable: false,
            mascot: PopMascotMood.crying,
            title: l10n.feedLoadError,
            action: PopButton(
              label: l10n.feedRetry,
              icon: Icons.refresh,
              onPressed: () => refreshFeed(showLoading: true),
            ),
          ),
        ),
      ];
    }

    if (_posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PopEmptyState(
            scrollable: false,
            mascot: PopMascotMood.confused,
            title: l10n.noPostsYet,
            message: l10n.publishFirstPostHint,
            action: widget.onPublishTap == null
                ? null
                : PopButton(
                    label: l10n.publishFirstPost,
                    icon: Icons.add_a_photo_outlined,
                    onPressed: widget.onPublishTap,
                  ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: listPadding,
        sliver: SliverList.separated(
          // The extra item closes the feed with the "all caught up" card.
          itemCount: _posts.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            if (index == _posts.length) return const _AllCaughtUpCard();
            final post = _posts[index];
            return PostCard(
              post: post,
              unknownUserLabel: l10n.unknownUser,
              onUpvote: () => _toggleUpvote(post.id),
            );
          },
        ),
      ),
    ];
  }
}

/// Yellow « défi de la semaine » card from the mockup, with its countdown
/// sticker and the shortcut to the camera.
class _ChallengeHero extends StatelessWidget {
  const _ChallengeHero({
    required this.challenge,
    required this.endsAt,
    this.onDoIt,
  });

  final FeedChallengeSummary challenge;
  final DateTime? endsAt;
  final VoidCallback? onDoIt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final description = challenge.description.trim();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: popCardDecoration(color: popYellow, radius: 26, shadow: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                challenge.isSpecial
                    ? l10n.homeSpecialChallenge
                    : l10n.homeWeeklyChallenge,
                style: popLabel(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Semantics(
                header: true,
                child: Text(challenge.title, style: popDisplay()),
              ),
              if (description.isNotEmpty && description != challenge.title) ...[
                const SizedBox(height: 8),
                Text(description, style: popBody()),
              ],
              if (onDoIt != null) ...[
                const SizedBox(height: 18),
                PopButton(
                  label: l10n.homeDoIt,
                  icon: Icons.photo_camera_outlined,
                  color: popInk,
                  onPressed: onDoIt,
                ),
              ],
            ],
          ),
        ),
        if (endsAt != null)
          Positioned(
            top: -14,
            right: 18,
            child: _CountdownSticker(endsAt: endsAt!),
          ),
      ],
    );
  }
}

class _CountdownSticker extends StatefulWidget {
  const _CountdownSticker({required this.endsAt});

  final DateTime endsAt;

  @override
  State<_CountdownSticker> createState() => _CountdownStickerState();
}

class _CountdownStickerState extends State<_CountdownSticker> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Minute precision is all the label shows.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final left = widget.endsAt.difference(DateTime.now());
    if (left.isNegative) return const SizedBox.shrink();

    final label = formatTimeLeft(left, l10n);
    return Semantics(
      label: l10n.challengeTimeLeft(label),
      excludeSemantics: true,
      child: PopSticker(
        label: label,
        color: popCoral,
        icon: Icons.timer_outlined,
        angle: 0.06,
        fontSize: 14,
      ),
    );
  }
}

/// Green « Tu es à jour ! » card closing the feed, with the happy bunny
/// stuck on its corner.
class _AllCaughtUpCard extends StatelessWidget {
  const _AllCaughtUpCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      // Room for the bunny, which sticks out above the card.
      padding: const EdgeInsets.only(top: 44),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 18, 86, 18),
            decoration: popCardDecoration(color: popGreen),
            child: Row(
              children: [
                Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: popCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: popInk, width: popStroke),
                    ),
                    child: const Icon(Icons.check_rounded, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.feedAllCaughtUpTitle, style: popTitle(fontSize: 19)),
                      const SizedBox(height: 2),
                      Text(l10n.feedAllCaughtUpMessage, style: popBody(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -46,
            right: -6,
            child: Transform.rotate(
              angle: 0.08,
              child: const PopMascot(PopMascotMood.happy, size: 104),
            ),
          ),
        ],
      ),
    );
  }
}
