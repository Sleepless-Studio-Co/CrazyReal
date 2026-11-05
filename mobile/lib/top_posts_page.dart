import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'l10n/app_localizations.dart';
import 'models/feed_post.dart';
import 'services/api_exception.dart';
import 'services/feed_service.dart';
import 'widgets/post_card.dart';
import 'widgets/post_card_skeleton.dart';

const Color _inkColor = Color(0xFF3B2A21);
const Color _inkMuted = Color(0xFF6A4A3B);
const Color _backgroundColor = Color(0xFFF7EBD1);

/// Couleurs des trois premières places (or, argent, bronze).
const List<Color> _podiumColors = [
  Color(0xFFC9A227),
  Color(0xFF9E9E9E),
  Color(0xFFB0703C),
];

/// Classement des posts les plus upvotés sur les défis globaux terminés.
class TopPostsPage extends StatefulWidget {
  const TopPostsPage({super.key, required this.onUnauthorized});

  final VoidCallback onUnauthorized;

  @override
  State<TopPostsPage> createState() => _TopPostsPageState();
}

class _TopPostsPageState extends State<TopPostsPage> {
  final FeedService _feedService = FeedService();

  List<FeedPost> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _period = 'all';

  @override
  void initState() {
    super.initState();
    _loadPosts(showLoading: true);
  }

  Future<void> _loadPosts({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final period = _period;
    try {
      final posts = await _feedService.fetchTopPosts(period);
      // Ignore une réponse arrivée après un changement de période.
      if (!mounted || period != _period) return;
      setState(() {
        _posts = posts;
        _isLoading = false;
        _errorMessage = null;
      });
    } on UnauthorizedException {
      _handleUnauthorized();
    } catch (e) {
      if (!mounted || period != _period) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _handleUnauthorized() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onUnauthorized();
  }

  void _selectPeriod(String period) {
    if (_period == period) return;
    setState(() => _period = period);
    _loadPosts(showLoading: true);
  }

  Future<void> _toggleUpvote(int postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final original = _posts[index];
    final wasUpvoted = original.hasUpvoted;

    // L'ordre du classement n'est pas recalculé localement : il sera mis à
    // jour au prochain rafraîchissement.
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
      _handleUnauthorized();
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = original);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _inkColor),
        title: Text(
          l10n.topPostsTitle,
          style: GoogleFonts.dmSerifDisplay(color: _inkColor, fontSize: 24),
        ),
      ),
      body: Column(
        children: [
          _buildPeriodFilter(l10n),
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildPeriodFilter(AppLocalizations l10n) {
    final periods = {
      'week': l10n.topPeriodWeek,
      'month': l10n.topPeriodMonth,
      'all': l10n.topPeriodAll,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        children: periods.entries.map((entry) {
          final selected = entry.key == _period;
          return ChoiceChip(
            label: Text(entry.value),
            selected: selected,
            showCheckmark: false,
            selectedColor: _inkColor,
            backgroundColor: const Color(0xFFFFF7E6),
            labelStyle: GoogleFonts.karla(
              color: selected ? Colors.white : _inkColor,
              fontWeight: FontWeight.w600,
            ),
            side: const BorderSide(color: Color(0xFFF0DFC2)),
            onSelected: (_) => _selectPeriod(entry.key),
          );
        }).toList(),
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
                onPressed: () => _loadPosts(showLoading: true),
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
        onRefresh: () => _loadPosts(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Icon(Icons.emoji_events_outlined,
                size: 64, color: _inkMuted.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                l10n.topPostsEmpty,
                style: _mutedStyle(),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPosts(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: _posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          final post = _posts[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRankLabel(index + 1),
              const SizedBox(height: 8),
              PostCard(
                post: post,
                unknownUserLabel: l10n.unknownUser,
                onUpvote: () => _toggleUpvote(post.id),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRankLabel(int rank) {
    final color =
        rank <= _podiumColors.length ? _podiumColors[rank - 1] : _inkMuted;

    return Row(
      children: [
        Icon(
          rank <= _podiumColors.length ? Icons.emoji_events : Icons.tag,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          '#$rank',
          style: GoogleFonts.dmSerifDisplay(color: color, fontSize: 20),
        ),
      ],
    );
  }

  TextStyle _mutedStyle({double fontSize = 14}) {
    return GoogleFonts.karla(color: _inkMuted, fontSize: fontSize);
  }
}
