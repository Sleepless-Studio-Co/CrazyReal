import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import 'paper.dart';

/// Profile card showing the user's global-challenge streak.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.streak});

  final UserStreak streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final active = streak.current > 0;
    final atRisk = active && streak.isAtRisk;

    final gradient = atRisk
        ? const [Color(0xFFFFF3D6), Color(0xFFFFD39E)]
        : active
            ? const [Color(0xFFFFF7E6), Color(0xFFFFE0BF)]
            : const [paperCard, paperCard];
    final border = atRisk
        ? const Color(0xFFE8A15C)
        : active
            ? const Color(0xFFF0C98F)
            : paperBorder;
    final badgeGradient = active
        ? const [Color(0xFFF08A4B), Color(0xFFC95524)]
        : const [Color(0xFFF0DFC2), Color(0xFFE3CBA8)];

    final footerText = atRisk
        ? l10n.streakAtRisk
        : active
            ? (streak.currentEdition == null
                ? l10n.streakNoChallenge
                : l10n.streakKeepGoing)
            : l10n.streakStartHint;

    return Semantics(
      container: true,
      label:
          '${l10n.streakCurrent}: ${streak.current}. ${l10n.streakBest}: ${streak.best}',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F2E1B0F),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: badgeGradient,
                    ),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: active ? Colors.white : paperAccentStrong,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.streakCurrent,
                        style: paperLabel(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: streak.current),
                            duration: const Duration(milliseconds: 550),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Text(
                              '$value',
                              style: paperTitle(
                                fontSize: 36,
                                color: active ? paperInk : paperInkMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              l10n.streakInARow,
                              style: paperMuted(fontSize: 13),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (streak.best > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          l10n.streakBest,
                          style: paperLabel(fontSize: 10),
                        ),
                        Text(
                          '${streak.best}',
                          style: paperValue(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    atRisk
                        ? Icons.warning_amber_rounded
                        : active
                            ? Icons.trending_up_rounded
                            : Icons.flag_outlined,
                    size: 18,
                    color: atRisk ? paperAccentStrong : paperInkMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      footerText,
                      style: paperMuted(
                        fontSize: 12.5,
                        color: atRisk ? paperAccentStrong : paperInkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
