import 'package:flutter/material.dart';

import 'auth/login_page.dart';
import 'auth/register_page.dart';
import 'l10n/app_localizations.dart';
import 'models/feed_post.dart';
import 'services/share_service.dart';
import 'widgets/post_card.dart';

class GuestSharePage extends StatefulWidget {
  const GuestSharePage({
    super.key,
    required this.token,
    required this.onAuthSuccess,
    this.isAuthenticated = false,
  });

  final String token;
  final VoidCallback onAuthSuccess;
  final bool isAuthenticated;

  @override
  State<GuestSharePage> createState() => _GuestSharePageState();
}

class _GuestSharePageState extends State<GuestSharePage> {
  final ShareService _shareService = ShareService();
  List<FeedPost> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await _shareService.fetchGuestFeed(widget.token);
      if (!mounted) return;
      setState(() {
        _posts = posts.take(2).toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _openAuth(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Text(
                      'Découvrez CrazyReal',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Vous pouvez parcourir deux photos du feed global. '
                      'Créez un compte pour continuer.',
                    ),
                    const SizedBox(height: 20),
                    ..._posts.map(
                      (post) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PostCard(
                          post: post,
                          unknownUserLabel: 'CrazyReal',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.isAuthenticated)
                      FilledButton(
                        onPressed: widget.onAuthSuccess,
                        child: const Text('Continuer vers le feed'),
                      )
                    else ...[
                      FilledButton(
                        onPressed: () => _openAuth(
                          LoginPage(onAuthSuccess: widget.onAuthSuccess),
                        ),
                        child: Text(l10n.login),
                      ),
                      OutlinedButton(
                        onPressed: () => _openAuth(
                          RegisterPage(onAuthSuccess: widget.onAuthSuccess),
                        ),
                        child: Text(l10n.register),
                      ),
                    ],
                  ],
                ),
    );
  }
}
