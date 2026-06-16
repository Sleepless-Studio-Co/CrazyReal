import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../services/chat_service.dart';
import '../services/api_exception.dart';

class GroupMembersPage extends StatefulWidget {
  final int conversationId;

  const GroupMembersPage({super.key, required this.conversationId});

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  List<dynamic> _members = [];
  int? _currentUserId;
  bool _isLoading = true;

  bool get _isCurrentUserAdmin {
    final me = _members.firstWhere(
      (m) => m['user']['id'] == _currentUserId,
      orElse: () => null,
    );
    return me != null && me['role'] == 'ADMIN';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getUser();
      final members = await _chatService.getMembers(widget.conversationId);
      if (mounted) {
        setState(() {
          _currentUserId = user?['id'] as int?;
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final message = e is ApiException ? e.message : 'Erreur lors du chargement des membres';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _promote(int userId) async {
    try {
      await _chatService.promoteMember(widget.conversationId, userId);
      _load();
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _demote(int userId) async {
    try {
      await _chatService.demoteMember(widget.conversationId, userId);
      _load();
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _remove(int userId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer du groupe'),
        content: Text('Veux-tu vraiment retirer $username du groupe ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Retirer')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _chatService.removeMember(widget.conversationId, userId);
      _load();
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  void _showError(Object error) {
    final message = error is ApiException ? error.message : 'Une erreur est survenue';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membres du groupe')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];
                  final user = member['user'];
                  final isAdmin = member['role'] == 'ADMIN';
                  final isMe = user['id'] == _currentUserId;

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(user['username'].toString().substring(0, 1).toUpperCase()),
                    ),
                    title: Text(user['username'] + (isMe ? ' (toi)' : '')),
                    subtitle: Text(isAdmin ? 'Admin' : 'Membre'),
                    trailing: (_isCurrentUserAdmin && !isMe)
                        ? PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'promote') _promote(user['id']);
                              if (action == 'demote') _demote(user['id']);
                              if (action == 'remove') _remove(user['id'], user['username']);
                            },
                            itemBuilder: (context) => [
                              if (!isAdmin)
                                const PopupMenuItem(value: 'promote', child: Text('Promouvoir admin')),
                              if (isAdmin)
                                const PopupMenuItem(value: 'demote', child: Text('Rétrograder membre')),
                              const PopupMenuItem(value: 'remove', child: Text('Retirer du groupe')),
                            ],
                          )
                        : null,
                  );
                },
              ),
            ),
    );
  }
}
