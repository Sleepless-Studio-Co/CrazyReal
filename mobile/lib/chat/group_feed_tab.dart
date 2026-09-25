import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/feed_post.dart';
import '../services/api_exception.dart';
import '../services/feed_service.dart';
import '../widgets/post_card.dart';

/// Onglet « Feed » d'un groupe : posts réalisés sur les défis du groupe.
/// Réutilise PostCard et les endpoints d'upvote existants.
class GroupFeedTab extends StatefulWidget {
  final int conversationId;

  const GroupFeedTab({super.key, required this.conversationId});

  @override
  State<GroupFeedTab> createState() => _GroupFeedTabState();
}

class _GroupFeedTabState extends State<GroupFeedTab> {
  final FeedService _feedService = FeedService();
  List<FeedPost> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await _feedService.fetchGroupPosts(widget.conversationId);
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : 'Erreur de chargement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts[index] = original);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'Aucune photo. Relevez un défi depuis l\'appareil photo !',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
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
          );
        },
      ),
    );
  }
}
