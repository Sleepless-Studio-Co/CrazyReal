import 'package:flutter/material.dart';
import 'paper.dart';

class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.paper.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.paper.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.paper.placeholder,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: context.paper.placeholder,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Container(color: context.paper.placeholder),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
