import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'l10n/app_localizations.dart';
import 'models/feed_post.dart';
import 'services/api_exception.dart';
import 'services/feed_service.dart';
import 'utils/media_url.dart';
import 'widgets/post_card.dart';
import 'widgets/post_card_skeleton.dart';

const Color _inkColor = Color(0xFF3B2A21);
const Color _inkMuted = Color(0xFF6A4A3B);

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
  String? _challengeSubtitle;
  List<AvailableChallenge> _availableChallenges = [];
  int _selectedChallengeId = -1;
  bool _showingGlobalFeed = true;
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
    _loadChallengeSubtitle();
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
        global: _selectedChallengeId == -1 ? _showingGlobalFeed : null,
      );
      if (!mounted) return;

      final visiblePosts = _filterPosts(posts);
      final shouldUpdate = !FeedPost.sameVoteState(_posts, visiblePosts);
      setState(() {
        if (shouldUpdate) {
          _posts = visiblePosts;
        }
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
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
      if (_selectedChallengeId == -1) {
        refreshFeed(showLoading: false);
      }
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

  Future<void> _selectFeedScope(
    BuildContext context,
    AppLocalizations l10n,
    bool showGlobal,
  ) async {
    if (_showingGlobalFeed == showGlobal) {
      await _openChallengeMenu(context, l10n);
      return;
    }

    setState(() {
      _showingGlobalFeed = showGlobal;
      _selectedChallengeId = -1;
    });
    refreshFeed(showLoading: true);
  }

  Future<void> _openChallengeMenu(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final selectedId = await showMenu<int>(
      context: context,
      color: const Color(0xFFF3D7B2),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height,
        offset.dx + renderBox.size.width,
        0,
      ),
      items: [
        PopupMenuItem<int>(
          value: -1,
          child: Text(
            l10n.feedAllChallenges,
            style: const TextStyle(color: _inkColor),
          ),
        ),
        ..._availableChallenges
            .where((challenge) => challenge.isGlobal == _showingGlobalFeed)
            .map(
              (challenge) => PopupMenuItem<int>(
                value: challenge.id,
                child: Text(
                  challenge.label(
                    l10n.feedGlobalChallenge,
                    l10n.feedFriendChallenge,
                  ),
                  style: const TextStyle(color: _inkColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
      ],
    );

    if (selectedId != null) {
      _selectChallenge(selectedId);
    }
  }

  List<FeedPost> _filterPosts(List<FeedPost> posts) {
    if (_selectedChallengeId != -1) {
      return posts
          .where((post) => post.challenge?.id == _selectedChallengeId)
          .toList();
    }

    final challengeIds = _availableChallenges
        .where((challenge) => challenge.isGlobal == _showingGlobalFeed)
        .map((challenge) => challenge.id)
        .toSet();
    return posts
        .where((post) => challengeIds.contains(post.challenge?.id))
        .toList();
  }

  Future<void> _loadChallengeSubtitle() async {
    final challenge = await _feedService.fetchCurrentChallenge();
    if (!mounted || challenge == null) return;

    final subtitle = challenge.description.isNotEmpty
        ? challenge.description
        : challenge.title;

    if (subtitle.isEmpty) return;

    setState(() => _challengeSubtitle = subtitle);
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

    return _availableChallenges.any(
      (challenge) =>
          challenge.id == challengeId &&
          challenge.isGlobal == _showingGlobalFeed,
    );
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

  Future<FeedPost> _toggleReaction(int postId, String emoji) async {
    final post = _posts.firstWhere((item) => item.id == postId);
    final reaction = post.reactions.firstWhere(
      (item) => item.emoji == emoji,
      orElse: () => const FeedReaction(
        emoji: '',
        count: 0,
        reactedByMe: false,
      ),
    );
    final updated = reaction.reactedByMe
        ? await _feedService.removeReaction(postId, emoji)
        : await _feedService.addReaction(postId, emoji);
    if (!mounted) return updated;
    final index = _posts.indexWhere((item) => item.id == postId);
    if (index != -1) setState(() => _posts[index] = updated);
    return updated;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7EBD1),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appTitle, style: _titleStyle()),
            if (_selectedChallengeId != -1 && _challengeSubtitle != null)
              Text(
                _challengeSubtitle!,
                style: _mutedStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
        ],
      ),
      body: Column(
        children: [
          _buildChallengeFilter(l10n),
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildChallengeFilter(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      color: const Color(0xFFF7EBD1),
      child: Column(
        children: [
          Builder(
            builder: (filterContext) => ToggleButtons(
              isSelected: [_showingGlobalFeed, !_showingGlobalFeed],
              onPressed: (index) =>
                  _selectFeedScope(filterContext, l10n, index == 0),
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.white,
              fillColor: _inkColor,
              color: _inkColor,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(l10n.feedGlobalChallenge),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(l10n.feedFriendChallenge),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => const PostCardSkeleton(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 48, color: _inkMuted.withValues(alpha: 0.8)),
              const SizedBox(height: 16),
              Text(
                l10n.feedLoadError,
                style: _mutedStyle(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => refreshFeed(showLoading: true),
                style: FilledButton.styleFrom(
                  backgroundColor: _inkColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.feedRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => refreshFeed(showLoading: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Icon(Icons.photo_camera_outlined,
                size: 64, color: _inkMuted.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Center(child: Text(l10n.noPostsYet, style: _mutedStyle())),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.publishFirstPostHint,
                style: _mutedStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            if (widget.onPublishTap != null)
              Center(
                child: FilledButton.icon(
                  onPressed: widget.onPublishTap,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(l10n.publishFirstPost),
                  style: FilledButton.styleFrom(
                    backgroundColor: _inkColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 120),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => refreshFeed(showLoading: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: _posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final post = _posts[index];
          return PostCard(
            post: post,
            unknownUserLabel: l10n.unknownUser,
            onUpvote: () => _toggleUpvote(post.id),
            onReaction: (emoji) => _toggleReaction(post.id, emoji),
          );
        },
      ),
    );
  }

  TextStyle _titleStyle() {
    return GoogleFonts.dmSerifDisplay(
      color: _inkColor,
      fontSize: 24,
      letterSpacing: 0.2,
    );
  }

  TextStyle _mutedStyle({double fontSize = 14}) {
    return GoogleFonts.karla(
      color: _inkMuted,
      fontSize: fontSize,
    );
  }
}
