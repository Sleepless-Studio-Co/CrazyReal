import 'dart:async';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'services/friend_service.dart';
import 'services/api_exception.dart';
import 'chat/create_group_page.dart';
import 'chat/chat_list_page.dart';

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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  void _openCreateGroup() {
    if (_friends.isEmpty) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Aucun ami'),
          content: const Text(
            "Tu n'as pas encore d'amis. Ajoute des amis avant de pouvoir créer un groupe.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupPage()),
    );
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
        appBar: AppBar(
          title: Text(l10n.myFriends), 
          actions: [
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatListPage()),
                );
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.myFriends),
              Tab(text: l10n.requests),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // --- ONGLET 1 : LA LISTE D'AMIS ---
                  RefreshIndicator(
                    onRefresh: _loadData,
                    child: _friends.isEmpty
                        ? ListView(children: [Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(l10n.noFriendsYet)))])
                        : ListView.builder(
                            itemCount: _friends.length,
                            itemBuilder: (context, index) {
                              final friend = _friends[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(friend['username'].toString().substring(0, 1).toUpperCase()),
                                ),
                                title: Text(friend['username']),
                                subtitle: Text(friend['email']),
                              );
                            },
                          ),
                  ),

                  RefreshIndicator(
                    onRefresh: _loadData,
                    child: _pendingRequests.isEmpty
                        ? ListView(children: [Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(l10n.noPendingRequests)))])
                        : ListView.builder(
                            itemCount: _pendingRequests.length,
                            itemBuilder: (context, index) {
                              final request = _pendingRequests[index];
                              final requester = request['requester'];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  child: Text(requester['username'].toString().substring(0, 1).toUpperCase()),
                                ),
                                title: Text(requester['username']),
                                subtitle: Text(l10n.wantsToBeYourFriend),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                                      tooltip: l10n.rejectRequest,
                                      onPressed: () => _rejectRequest(request['requestId']),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                                      onPressed: () => _acceptRequest(request['requestId']),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.small(
              heroTag: 'createGroup',
              onPressed: _openCreateGroup,
              tooltip: l10n.group,
              child: const Icon(Icons.group_add),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'addFriend',
              onPressed: _showAddFriendDialog,
              icon: const Icon(Icons.person_add),
              label: Text(l10n.addFriend),
            ),
          ],
        ),
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.message : l10n.friendRequestError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                l10n.addFriend,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: l10n.searchUsersHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
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
      return Center(child: Text(l10n.noUsersFound));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index] as Map<String, dynamic>;
        final isPrivate = user['isPrivate'] == true;
        final alreadySent = _sent.contains(user['id']);
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              user['username'].toString().substring(0, 1).toUpperCase(),
            ),
          ),
          title: Text(user['username']),
          subtitle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPrivate ? Icons.lock : Icons.public,
                size: 14,
                color: isPrivate ? Colors.orange : Colors.green,
              ),
              const SizedBox(width: 4),
              Text(isPrivate ? l10n.accountPrivate : l10n.accountPublic),
            ],
          ),
          trailing: alreadySent
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 18),
                    const SizedBox(width: 4),
                    Text(l10n.requestSentShort),
                  ],
                )
              : IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: l10n.send,
                  onPressed: () => _send(user),
                ),
        );
      },
    );
  }
}