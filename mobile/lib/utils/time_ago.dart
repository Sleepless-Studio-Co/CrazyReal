import '../l10n/app_localizations.dart';

String formatTimeAgo(DateTime date, AppLocalizations l10n) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 1) {
    return l10n.feedJustNow;
  }
  if (diff.inHours < 1) {
    return l10n.timeAgoMinutes(diff.inMinutes);
  }
  if (diff.inDays < 1) {
    return l10n.timeAgoHours(diff.inHours);
  }
  if (diff.inDays < 7) {
    return l10n.timeAgoDays(diff.inDays);
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// Time left before a challenge ends, rounded down except for the last
/// minute so "0 min" is never shown while it is still running.
String formatTimeLeft(Duration left, AppLocalizations l10n) {
  if (left.inDays >= 1) {
    return l10n.challengeEndsInDays(left.inDays, left.inHours.remainder(24));
  }
  if (left.inHours >= 1) {
    return l10n.challengeEndsInHours(
        left.inHours, left.inMinutes.remainder(60));
  }
  return l10n.challengeEndsInMinutes(left.inMinutes < 1 ? 1 : left.inMinutes);
}
