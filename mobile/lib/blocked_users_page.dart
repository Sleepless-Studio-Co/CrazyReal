import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'services/api_exception.dart';
import 'services/friend_service.dart';
import 'widgets/feed_avatar.dart';
import 'widgets/paper.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final FriendService _friendService = FriendService();
  List<dynamic> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final users = await _friendService.getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUsers = users;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiException
              ? error.message
              : AppLocalizations.of(context)!.error),
          backgroundColor: paperDanger,
        ),
      );
    }
  }

  Future<void> _unblock(Map<String, dynamic> user) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _friendService.unblockUser(user['id'] as int);
      if (mounted) {
        setState(() {
          _blockedUsers.removeWhere((item) => item['id'] == user['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.userUnblocked), backgroundColor: paperSuccess),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error is ApiException ? error.message : l10n.error),
            backgroundColor: paperDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.paper.bg,
      appBar: paperAppBar(context, title: l10n.blockedUsers),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.paper.accent))
          : RefreshIndicator(
              onRefresh: _load,
              color: context.paper.accent,
              child: _blockedUsers.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.sizeOf(context).height * .25),
                        PaperEmptyState(
                          icon: Icons.block_outlined,
                          title: l10n.noBlockedUsers,
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _blockedUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final user = _blockedUsers[index] as Map<String, dynamic>;
                        final username = user['username']?.toString() ?? '';
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: paperCardDecoration(context),
                          child: Row(
                            children: [
                              FeedAvatar(
                                username: username,
                                avatarUrl: user['avatarUrl']?.toString(),
                                avatarKey: user['avatarKey']?.toString(),
                                userId: user['id'] as int?,
                                size: 46,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(username, style: paperValue(context)),
                              ),
                              TextButton(
                                onPressed: () => _unblock(user),
                                child: Text(l10n.unblock),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
