import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'l10n/app_localizations.dart';

class BannedPage extends StatelessWidget {
  const BannedPage(
      {super.key, required this.reason, required this.onLoggedOut});

  final String? reason;
  final VoidCallback onLoggedOut;

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    onLoggedOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 64, color: Color(0xFFB54132)),
              const SizedBox(height: 20),
              Text(
                l10n.accountBannedTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                reason == null || reason!.trim().isEmpty
                    ? l10n.accountBannedMessage
                    : l10n.accountBannedReason(reason!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: Text(l10n.logout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
