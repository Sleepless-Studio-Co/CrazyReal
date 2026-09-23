import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';
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

  Future<void> _openAddMembers() async {
    final memberIds = _members
        .map((m) => (m['user'] as Map)['id'] as int)
        .toSet();

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: paperCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddMembersSheet(
        conversationId: widget.conversationId,
        existingMemberIds: memberIds,
      ),
    );

    if (added == true && mounted) _load();
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
      // Le backend n'autorise l'ajout qu'aux admins : on ne propose donc le
      // bouton qu'à eux.
      floatingActionButton: (_isLoading || !_isCurrentUserAdmin)
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddMembers,
              backgroundColor: paperAccentStrong,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text('Ajouter', style: paperValue(color: Colors.white)),
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

/// Feuille d'ajout de membres : liste les amis qui ne sont pas déjà dans le
/// groupe (le backend refuse les non-amis, autant ne pas les proposer).
class _AddMembersSheet extends StatefulWidget {
  const _AddMembersSheet({
    required this.conversationId,
    required this.existingMemberIds,
  });

  final int conversationId;
  final Set<int> existingMemberIds;

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();

  List<dynamic> _candidates = [];
  final Set<int> _selected = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final friends = await _friendService.getFriends();
      if (!mounted) return;
      setState(() {
        _candidates = friends
            .where((f) => !widget.existingMemberIds.contains(f['id']))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e is ApiException ? e.message : 'Erreur lors du chargement des amis');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: paperDanger),
    );
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await _chatService.addMembers(widget.conversationId, _selected.toList());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(e is ApiException ? e.message : "Erreur lors de l'ajout");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                header: true,
                child: Text('Ajouter des membres', style: paperTitle()),
              ),
            ),
          ),
          Expanded(child: _buildList()),
          if (_candidates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _selected.isEmpty || _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: Text('Ajouter (${_selected.length})'),
                  style: FilledButton.styleFrom(
                    backgroundColor: paperAccentStrong,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    textStyle: paperValue(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: paperAccent));
    }

    if (_candidates.isEmpty) {
      return const PaperEmptyState(
        icon: Icons.group_outlined,
        title: 'Aucun ami à ajouter',
        message: 'Tous tes amis sont déjà dans ce groupe.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      itemCount: _candidates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final friend = _candidates[index] as Map<String, dynamic>;
        final username = friend['username']?.toString() ?? '';
        final id = friend['id'] as int;
        final isSelected = _selected.contains(id);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? paperAccent : paperBorder,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (checked) => setState(() {
              if (checked == true) {
                _selected.add(id);
              } else {
                _selected.remove(id);
              }
            }),
            activeColor: paperAccentStrong,
            controlAffinity: ListTileControlAffinity.trailing,
            title: Text(username, style: paperValue()),
            secondary: ExcludeSemantics(
              child: FeedAvatar(
                username: username,
                avatarUrl: friend['avatarUrl']?.toString(),
                avatarKey: friend['avatarKey']?.toString(),
                size: 42,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
        );
      },
    );
  }
}
