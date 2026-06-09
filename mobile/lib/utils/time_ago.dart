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
