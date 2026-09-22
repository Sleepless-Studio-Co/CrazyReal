import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../services/chat_service.dart';
import '../services/api_exception.dart';
import '../widgets/feed_avatar.dart';
import '../widgets/paper.dart';

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
          SnackBar(content: Text(message), backgroundColor: paperDanger),
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
    final confirmed = await paperConfirm(
      context,
      title: 'Retirer du groupe',
      message: 'Veux-tu vraiment retirer $username du groupe ?',
      confirmLabel: 'Retirer',
      cancelLabel: 'Annuler',
      danger: true,
    );

    if (!confirmed) return;

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
      SnackBar(content: Text(message), backgroundColor: paperDanger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paperBg,
      appBar: paperAppBar(
        title: 'Membres',
        subtitle: _isLoading ? null : '${_members.length} membre(s)',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: paperAccent))
          : RefreshIndicator(
              onRefresh: _load,
              color: paperAccent,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                itemCount: _members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final member = _members[index];
                  final user = member['user'] as Map<String, dynamic>;
                  final username = user['username']?.toString() ?? '';
                  final isAdmin = member['role'] == 'ADMIN';
                  final isMe = user['id'] == _currentUserId;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: paperCardDecoration(),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: FeedAvatar(
                            username: username,
                            avatarUrl: user['avatarUrl']?.toString(),
                            avatarKey: user['avatarKey']?.toString(),
                            size: 46,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: MergeSemantics(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMe ? '$username (toi)' : username,
                                  style: paperValue(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                _RoleChip(isAdmin: isAdmin),
                              ],
                            ),
                          ),
                        ),
                        if (_isCurrentUserAdmin && !isMe)
                          PopupMenuButton<String>(
                            tooltip: 'Gérer $username',
                            icon: const Icon(Icons.more_vert),
                            color: paperCard,
                            iconColor: paperInk,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            onSelected: (action) {
                              if (action == 'promote') _promote(user['id']);
                              if (action == 'demote') _demote(user['id']);
                              if (action == 'remove') {
                                _remove(user['id'], username);
                              }
                            },
                            itemBuilder: (context) => [
                              if (!isAdmin)
                                PopupMenuItem(
                                  value: 'promote',
                                  child: Text('Promouvoir admin',
                                      style: paperValue(fontSize: 14)),
                                ),
                              if (isAdmin)
                                PopupMenuItem(
                                  value: 'demote',
                                  child: Text('Rétrograder membre',
                                      style: paperValue(fontSize: 14)),
                                ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text(
                                  'Retirer du groupe',
                                  style: paperValue(
                                    fontSize: 14,
                                    color: paperDanger,
                                  ),
                                ),
                              ),
                            ],
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

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: paperChip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              isAdmin ? Icons.shield_outlined : Icons.person_outline,
              size: 13,
              color: paperInkMuted,
            ),
          ),
          const SizedBox(width: 4),
          Text(isAdmin ? 'Admin' : 'Membre', style: paperLabel(fontSize: 11)),
        ],
      ),
    );
  }
}
