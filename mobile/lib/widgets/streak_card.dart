import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user_streak.dart';
import 'paper.dart';

/// Profile card showing the user's consecutive global-challenge streak.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.streak});

  final UserStreak streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.paper;
    final active = streak.current > 0;
    final atRisk = active && streak.isAtRisk;

    final gradient = atRisk
        ? [palette.card, palette.chip]
        : active
            ? [palette.heroStart, palette.heroEnd]
            : [palette.card, palette.card];
    final border = atRisk ? palette.accent : palette.border;
    final badgeColor = active ? palette.accent : palette.chip;
    final badgeIconColor = active ? palette.bg : palette.inkMuted;

    final footerText = atRisk
        ? l10n.streakAtRisk
        : active
            ? (streak.currentEdition == null
                ? l10n.streakNoChallenge
                : l10n.streakKeepGoing)
            : streak.best > 0
                ? l10n.streakRestartHint
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
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 18,
              offset: const Offset(0, 10),
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
                    color: badgeColor,
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: badgeIconColor,
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
                        style: paperLabel(context, fontSize: 12),
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
                                context,
                                fontSize: 36,
                                color: active ? palette.ink : palette.inkMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              l10n.streakInARow,
                              style: paperMuted(context, fontSize: 13),
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
                      color: palette.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          l10n.streakBest,
                          style: paperLabel(context, fontSize: 10),
                        ),
                        Text(
                          '${streak.best}',
                          style: paperValue(context, fontSize: 18),
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
                color: palette.field,
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
                    color: atRisk ? palette.accent : palette.inkMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      footerText,
                      style: paperMuted(
                        context,
                        fontSize: 12.5,
                        color: atRisk ? palette.accent : palette.inkMuted,
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
