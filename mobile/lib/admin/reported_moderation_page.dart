import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'reported_posts_page.dart';
import 'reported_users_page.dart';

class ReportedModerationPage extends StatelessWidget {
  const ReportedModerationPage({super.key, required this.onUnauthorized});

  final VoidCallback onUnauthorized;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminModerationTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ModerationBlock(
            icon: Icons.photo_library_outlined,
            title: l10n.adminReportedPostsTitle,
            subtitle: l10n.adminReportedPostsDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ReportedPostsPage(onUnauthorized: onUnauthorized),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ModerationBlock(
            icon: Icons.people_outline,
            title: l10n.adminReportedUsersTitle,
            subtitle: l10n.adminReportedUsersDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ReportedUsersPage(onUnauthorized: onUnauthorized),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationBlock extends StatelessWidget {
  const _ModerationBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
