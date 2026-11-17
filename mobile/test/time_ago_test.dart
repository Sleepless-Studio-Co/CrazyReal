import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations_en.dart';
import 'package:mobile/utils/time_ago.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('shows "Just now" for very recent timestamps', () {
    expect(formatTimeAgo(DateTime.now(), l10n), 'Just now');
  });

  test('formats minutes ago', () {
    final date = DateTime.now().subtract(const Duration(minutes: 5));
    expect(formatTimeAgo(date, l10n), '5 min ago');
  });

  test('formats hours ago', () {
    final date = DateTime.now().subtract(const Duration(hours: 3));
    expect(formatTimeAgo(date, l10n), '3 h ago');
  });

  test('formats days ago', () {
    final date = DateTime.now().subtract(const Duration(days: 2));
    expect(formatTimeAgo(date, l10n), '2 d ago');
  });

  test('falls back to a DD/MM/YYYY date beyond a week', () {
    final date = DateTime(2025, 3, 7);
    expect(formatTimeAgo(date, l10n), '07/03/2025');
  });
}
