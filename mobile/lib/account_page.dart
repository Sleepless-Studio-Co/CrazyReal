import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountPage),
      ),
      body: Center(
        child: Text(l10n.thisAccountPage),
      ),
    );
  }
}