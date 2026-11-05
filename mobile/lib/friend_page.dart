import 'dart:async';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'services/friend_service.dart';
import 'services/api_exception.dart';
import 'chat/chat_list_page.dart';
import 'widgets/feed_avatar.dart';
import 'widgets/sticker_pop.dart';

class FriendPage extends StatefulWidget {

  final VoidCallback onUnauthorized;

  const FriendPage({super.key, required this.onUnauthorized});

  @override
  State<FriendPage> createState() => _FriendPageState();
}

class _FriendPageState extends State<FriendPage> {
  final FriendService _friendService = FriendService();

  List<dynamic> _friends = [];
  List<dynamic> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _friendService.getFriends(),
        _friendService.getPendingRequests(),
      ]);

      if (mounted) {
        setState(() {
          _friends = results[0];
          _pendingRequests = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e is UnauthorizedException && mounted) {
        widget.onUnauthorized();
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError(e);
        }
      }
    }
  }

  void _showError(Object error) {
    final message = error is ApiException ? error.message : AppLocalizations.of(context)!.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: popCoral),
    );
  }

  Future<void> _acceptRequest(int requestId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _friendService.acceptRequest(requestId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.friendRequestAccepted),
            backgroundColor: popGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _rejectRequest(int requestId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _friendService.rejectRequest(requestId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.friendRequestRejected),
            backgroundColor: popGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  void _showAddFriendDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AddFriendSheet(friendService: _friendService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: popAppBar(
          title: l10n.myFriends,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: PopIconButton(
                icon: Icons.forum_outlined,
                tooltip: l10n.messages,
                size: 44,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ChatListPage()),
                  );
                },
              ),
            ),
          ],
          bottom: popTabBar([
            Tab(text: '${l10n.friends} (${_friends.length})'),
            Tab(text: '${l10n.requests} (${_pendingRequests.length})'),
          ]),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildFriendsTab(l10n),
                  _buildRequestsTab(l10n),
                ],
              ),
        floatingActionButton: PopButton(
          onPressed: _showAddFriendDialog,
          icon: Icons.person_add_alt_1,
          label: l10n.addFriend,
        ),
      ),
    );
  }

  Widget _buildFriendsTab(AppLocalizations l10n) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _friends.isEmpty
          ? PopEmptyState(
              mascot: PopMascotMood.confused,
              title: l10n.noFriendsYet,
              action: PopButton(
                onPressed: _showAddFriendDialog,
                icon: Icons.person_add_alt_1,
                label: l10n.addFriend,
              ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              // Bottom padding clears the floating action button.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _friends.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final friend = _friends[index] as Map<String, dynamic>;
                return _FriendCard(friend: friend);
              },
            ),
    );
  }

  Widget _buildRequestsTab(AppLocalizations l10n) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _pendingRequests.isEmpty
          ? PopEmptyState(
              icon: Icons.mark_email_read_outlined,
              title: l10n.noPendingRequests,
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _pendingRequests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final request = _pendingRequests[index];
                final requester = request['requester'] as Map<String, dynamic>;
                return _RequestCard(
                  requester: requester,
                  onAccept: () => _acceptRequest(request['requestId']),
                  onReject: () => _rejectRequest(request['requestId']),
                );
              },
            ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friend});

  final Map<String, dynamic> friend;

  @override
  Widget build(BuildContext context) {
    final username = friend['username']?.toString() ?? '';
    final email = friend['email']?.toString() ?? '';
    final isPrivate = friend['isPrivate'] == true;
    final l10n = AppLocalizations.of(context)!;

    // One tile = one announcement for screen readers instead of three fragments.
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: popCardDecoration(shadow: 4),
        child: Row(
          children: [
            ExcludeSemantics(
              child: FeedAvatar(
                username: username,
                avatarUrl: friend['avatarUrl']?.toString(),
                avatarKey: friend['avatarKey']?.toString(),
                size: 48,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(username, style: popTitle(fontSize: 17)),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: popMuted(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _PrivacyChip(
              isPrivate: isPrivate,
              label: isPrivate ? l10n.accountPrivate : l10n.accountPublic,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.requester,
    required this.onAccept,
    required this.onReject,
  });

  final Map<String, dynamic> requester;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final username = requester['username']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: popCardDecoration(shadow: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
              children: [
                ExcludeSemantics(
                  child: FeedAvatar(
                    username: username,
                    avatarUrl: requester['avatarUrl']?.toString(),
                    avatarKey: requester['avatarKey']?.toString(),
                    size: 48,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username, style: popTitle(fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(l10n.wantsToBeYourFriend, style: popMuted()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Labelled buttons rather than bare icons: the action and the person
          // it applies to are both announced.
          Row(
            children: [
              Expanded(
                child: PopButton(
                  onPressed: onReject,
                  icon: Icons.close,
                  label: l10n.rejectRequest,
                  color: popCard,
                  foreground: popInk,
                  dense: true,
                  expand: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PopButton(
                  onPressed: onAccept,
                  icon: Icons.check,
                  label: l10n.acceptRequest,
                  color: popGreen,
                  foreground: popInk,
                  dense: true,
                  expand: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrivacyChip extends StatelessWidget {
  const _PrivacyChip({required this.isPrivate, required this.label});

  final bool isPrivate;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: popBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: popInk, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The icon repeats the label, so it carries no extra meaning.
          ExcludeSemantics(
            child: Icon(
              isPrivate ? Icons.lock_outline : Icons.public,
              size: 14,
              color: popInk,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: popValue(fontSize: 12)),
        ],
      ),
    );
  }
}

class _AddFriendSheet extends StatefulWidget {
  final FriendService friendService;

  const _AddFriendSheet({required this.friendService});

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<dynamic> _results = [];
  bool _loading = false;
  final Set<int> _sent = {};

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final results = await widget.friendService.searchUsers(query);
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _send(Map<String, dynamic> user) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await widget.friendService.sendRequest(user['username']);
      if (mounted) {
        setState(() => _sent.add(user['id']));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.friendRequestSent(user['username'])),
            backgroundColor: popGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.message : l10n.friendRequestError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: popCoral),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      // Lift the sheet above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  header: true,
                  child: Text(l10n.addFriend, style: popTitle()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                style: popValue(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: l10n.searchUsersHint,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildResults(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(l10n.noUsersFound, style: popMuted(fontSize: 15)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = _results[index] as Map<String, dynamic>;
        final username = user['username'].toString();
        final isPrivate = user['isPrivate'] == true;
        final alreadySent = _sent.contains(user['id']);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: popCardDecoration(radius: 16, shadow: 0),
          child: Row(
            children: [
              ExcludeSemantics(
                child: FeedAvatar(
                  username: username,
                  avatarUrl: user['avatarUrl']?.toString(),
                  avatarKey: user['avatarKey']?.toString(),
                  size: 42,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username, style: popValue(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        isPrivate ? l10n.accountPrivate : l10n.accountPublic,
                        style: popMuted(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (alreadySent)
                PopSticker(
                  label: l10n.requestSentShort,
                  icon: Icons.check,
                  color: popGreen,
                  angle: 0.04,
                  fontSize: 12,
                )
              else
                PopIconButton(
                  icon: Icons.person_add_alt_1,
                  color: popPurple,
                  foreground: Colors.white,
                  size: 44,
                  // Names the person, so the button is unambiguous out of context.
                  tooltip: '${l10n.send} — $username',
                  onPressed: () => _send(user),
                ),
            ],
          ),
        );
      },
    );
  }
}
