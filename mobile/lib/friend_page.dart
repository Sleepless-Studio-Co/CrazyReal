import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';

class FriendPage extends StatelessWidget {
  const FriendPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.friendPage),
      ),
      body: Center(
        child: Text(l10n.thisFriendPage),
      ),
    );
  }
}