import 'package:flutter/material.dart';

import 'sticker_pop.dart';

class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: popCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: popBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: popInk, width: popStroke),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: popBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Container(
              decoration: BoxDecoration(
                color: popPhoto,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: popInk, width: popStroke),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 120,
            height: 44,
            decoration: BoxDecoration(
              color: popBg,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }
}
