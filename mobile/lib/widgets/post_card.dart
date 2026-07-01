import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/feed_post.dart';
import '../utils/media_url.dart';
import '../utils/time_ago.dart';
import 'feed_avatar.dart';
import 'full_screen_photo_page.dart';

const Color _inkColor = Color(0xFF3B2A21);
const Color _inkMuted = Color(0xFF6A4A3B);
const Color _cardColor = Color(0xFFFFF7E6);

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.unknownUserLabel,
    this.onUpvote,
  });

  final FeedPost post;
  final String unknownUserLabel;
  final VoidCallback? onUpvote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final username = post.user.username.isEmpty
        ? unknownUserLabel
        : post.user.username;
    final photoUrl = resolveMediaUrl(post.photoUrl) ?? '';
    final challengeLabel =
        post.challenge?.title.isNotEmpty == true ? post.challenge!.title : l10n.appTitle;
    final timeLabel = post.createdAt != null
        ? formatTimeAgo(post.createdAt!, l10n)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0DFC2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2E1B0F),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                FeedAvatar(
                  username: post.user.username,
                  avatarUrl: post.user.avatarUrl,
                  avatarKey: post.user.avatarKey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: _valueStyle(),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (timeLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          timeLabel,
                          style: _mutedStyle(fontSize: 12.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: photoUrl.isEmpty
                ? null
                : () => FullScreenPhotoPage.open(
                      context,
                      imageUrl: photoUrl,
                      heroTag: 'post-photo-${post.id}',
                      caption: challengeLabel,
                    ),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: Hero(
                tag: 'post-photo-${post.id}',
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFFEEDCC5),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFEEDCC5),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: _inkMuted,
                          size: 42,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      challengeLabel,
                      style: _labelStyle(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onUpvote,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          post.hasUpvoted ? Icons.favorite : Icons.favorite_border,
                          color: post.hasUpvoted ? const Color(0xFFE05252) : _inkMuted,
                          size: 22,
                        ),
                        if (post.upvoteCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${post.upvoteCount}',
                            style: _labelStyle().copyWith(
                              color: post.hasUpvoted ? const Color(0xFFE05252) : _inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle() {
    return GoogleFonts.karla(
      color: _inkMuted,
      fontSize: 12.5,
      letterSpacing: 0.2,
      fontWeight: FontWeight.w600,
    );
  }

  TextStyle _valueStyle() {
    return GoogleFonts.karla(
      color: _inkColor,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
  }

  TextStyle _mutedStyle({double fontSize = 14}) {
    return GoogleFonts.karla(
      color: _inkMuted,
      fontSize: fontSize,
    );
  }
}
