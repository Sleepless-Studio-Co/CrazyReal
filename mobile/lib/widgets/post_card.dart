import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/feed_post.dart';
import '../utils/media_url.dart';
import '../utils/time_ago.dart';
import 'feed_avatar.dart';
import 'full_screen_photo_page.dart';
import 'full_screen_video_page.dart';
import 'sticker_pop.dart';

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

    // « Challenge · 12 min », like the « group · time » line of the mockup.
    final caption = [
      if (post.challenge?.title.isNotEmpty == true) post.challenge!.title,
      if (timeLabel != null) timeLabel,
    ].join(' · ');
    final upvoteLabel = post.hasUpvoted ? l10n.postUpvoted : l10n.postUpvote;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: popCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FeedAvatar(
                username: post.user.username,
                avatarUrl: post.user.avatarUrl,
                avatarKey: post.user.avatarKey,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: popTitle(fontSize: 17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        caption,
                        style: popMuted(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
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
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: popPhoto,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  // Drawn over the photo, which would otherwise hide it.
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: popInk, width: popStroke),
                  ),
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
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: popInk,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: popInk,
                                    size: 42,
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                left: -6,
                bottom: 16,
                child: PopSticker(
                  label: l10n.postChallengeDone,
                  icon: Icons.check_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              PopButton(
                label: post.upvoteCount > 0
                    ? '$upvoteLabel · ${post.upvoteCount}'
                    : upvoteLabel,
                semanticLabel:
                    '$upvoteLabel, ${l10n.postUpvoteCount(post.upvoteCount)}',
                icon: Icons.arrow_upward_rounded,
                color: post.hasUpvoted ? popCoral : popCard,
                foreground: popInk,
                dense: true,
                onPressed: onUpvote,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: PopButton(
                  label: l10n.postShare,
                  icon: Icons.share_outlined,
                  color: popCard,
                  foreground: popInk,
                  dense: true,
                  onPressed: photoUrl.isEmpty
                      ? null
                      : () => SharePlus.instance
                          .share(ShareParams(uri: Uri.parse(photoUrl))),
                ),
              ),
            ],
          ),
        ],
      ),
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
            return const Center(
              child: Icon(
                Icons.videocam_outlined,
                color: popInk,
                size: 56,
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
