import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../l10n/app_localizations.dart';
import '../models/feed_post.dart';
import '../utils/media_url.dart';
import '../utils/time_ago.dart';
import 'feed_avatar.dart';
import 'full_screen_photo_page.dart';
import 'full_screen_video_page.dart';

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
                : () {
                    if (post.isVideo) {
                      _VideoPreview.pauseActiveVideo();
                      FullScreenVideoPage.open(
                        context,
                        videoUrl: photoUrl,
                        caption: challengeLabel,
                      );
                    } else {
                      FullScreenPhotoPage.open(
                        context,
                        imageUrl: photoUrl,
                        heroTag: 'post-photo-${post.id}',
                        caption: challengeLabel,
                      );
                    }
                  },
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: post.isVideo
                  ? _VideoPreview(mediaUrl: photoUrl)
                  : Hero(
                      tag: 'post-photo-${post.id}',
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFFEEDCC5),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
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

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.mediaUrl});

  final String mediaUrl;

  static void pauseActiveVideo() {
    _VideoPreviewState._activePreview?._pauseForAnotherVideo();
    _VideoPreviewState._activePreview = null;
  }

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  static _VideoPreviewState? _activePreview;

  late final VideoPlayerController _controller;
  late final Future<void> _initializeFuture;
  double _visibleFraction = 0;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));
    _initializeFuture = _controller.initialize().then((_) async {
      await _controller.setLooping(true);
      await _controller.setVolume(0);
      if (_visibleFraction >= 0.6) {
        _playIfVisible();
      }
    });
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    _visibleFraction = info.visibleFraction;
    if (_visibleFraction >= 0.6) {
      _playIfVisible();
    } else if (_controller.value.isPlaying) {
      _controller.pause();
      if (identical(_activePreview, this)) _activePreview = null;
    }
  }

  void _playIfVisible() {
    if (!mounted || !_controller.value.isInitialized || _visibleFraction < 0.6) {
      return;
    }

    if (_activePreview != null && !identical(_activePreview, this)) {
      _activePreview!._pauseForAnotherVideo();
    }
    _activePreview = this;
    _controller.play();
  }

  void _pauseForAnotherVideo() {
    if (_controller.value.isPlaying) _controller.pause();
  }

  @override
  void dispose() {
    if (identical(_activePreview, this)) _activePreview = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video-${widget.mediaUrl}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              snapshot.hasError) {
            return Container(
              color: const Color(0xFF2A211C),
              child: const Center(
                child: Icon(
                  Icons.videocam_outlined,
                  color: Colors.white38,
                  size: 56,
                ),
              ),
            );
          }

          return FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          );
        },
      ),
    );
  }
}
