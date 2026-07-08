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
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController usernameController = TextEditingController();
    final scaffoldContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.addFriend),
        content: TextField(
          controller: usernameController,
          decoration: InputDecoration(
            labelText: l10n.friendUsernameLabel,
            hintText: l10n.friendUsernameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final username = usernameController.text.trim();
              if (username.isNotEmpty) {
                Navigator.pop(dialogContext);
                try {
                  await _friendService.sendRequest(username);
                  if (mounted) {
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                      SnackBar(
                        content: Text(l10n.friendRequestSent(username)),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    final message = e is ApiException ? e.message : l10n.friendRequestError;
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                      SnackBar(content: Text(message), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: Text(l10n.send),
          ),
        ],
      ),
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
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showAddFriendDialog,
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreateGroup,
          label: Text(l10n.group),
          icon: const Icon(Icons.group_add),
        ),
      ),
    );
  }
}