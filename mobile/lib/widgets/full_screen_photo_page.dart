import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FullScreenPhotoPage extends StatelessWidget {
  const FullScreenPhotoPage({
    super.key,
    required this.imageUrl,
    this.heroTag,
    this.caption,
  });

  final String imageUrl;
  final String? heroTag;
  final String? caption;

  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    String? heroTag,
    String? caption,
  }) {
    if (imageUrl.isEmpty) return Future.value();

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => FullScreenPhotoPage(
          imageUrl: imageUrl,
          heroTag: heroTag,
          caption: caption,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 64,
          ),
        );
      },
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: heroTag != null
                    ? Hero(tag: heroTag!, child: image)
                    : image,
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ),
            ),
            if (caption != null && caption!.isNotEmpty)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Text(
                      caption!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
