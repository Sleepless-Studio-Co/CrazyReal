import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';
import '../services/api_exception.dart';
import '../widgets/feed_avatar.dart';
import '../widgets/sticker_pop.dart';

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
          SnackBar(content: Text(message), backgroundColor: popCoral),
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
    final confirmed = await popConfirm(
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
      SnackBar(content: Text(message), backgroundColor: popCoral),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: popAppBar(
        title: 'Membres',
        subtitle: _isLoading ? null : '${_members.length} membre(s)',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
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
                    decoration: popCardDecoration(shadow: 4),
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
                                  style: popTitle(fontSize: 17),
                                ),
                                const SizedBox(height: 6),
                                _RoleChip(isAdmin: isAdmin),
                              ],
                            ),
                          ),
                        ),
                        if (_isCurrentUserAdmin && !isMe)
                          PopupMenuButton<String>(
                            tooltip: 'Gérer $username',
                            icon: const Icon(Icons.more_vert),
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
                                      style: popValue(fontSize: 14)),
                                ),
                              if (isAdmin)
                                PopupMenuItem(
                                  value: 'demote',
                                  child: Text('Rétrograder membre',
                                      style: popValue(fontSize: 14)),
                                ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text(
                                  'Retirer du groupe',
                                  style: popValue(
                                    fontSize: 14,
                                    color: popDanger,
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
          : PopButton(
              onPressed: _openAddMembers,
              icon: Icons.person_add_alt_1,
              label: 'Ajouter',
            ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return PopSticker(
      label: isAdmin ? 'Admin' : 'Membre',
      icon: isAdmin ? Icons.shield_outlined : Icons.person_outline,
      color: isAdmin ? popYellow : popBg,
      angle: isAdmin ? -0.04 : 0,
      fontSize: 12,
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
      SnackBar(content: Text(message), backgroundColor: popCoral),
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
                child: Text('Ajouter des membres', style: popTitle()),
              ),
            ),
          ),
          Expanded(child: _buildList()),
          if (_candidates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: PopButton(
                onPressed: _selected.isEmpty ? null : _submit,
                loading: _isSubmitting,
                icon: Icons.person_add_alt_1,
                label: 'Ajouter (${_selected.length})',
                expand: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_candidates.isEmpty) {
      return const PopEmptyState(
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

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: popCardDecoration(
            color: isSelected ? popYellow : popCard,
            radius: 16,
            shadow: isSelected ? 3 : 0,
          ),
          clipBehavior: Clip.antiAlias,
          // Transparent material so the tile's ink shows above the card colour.
          child: Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: isSelected,
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selected.add(id);
                } else {
                  _selected.remove(id);
                }
              }),
              controlAffinity: ListTileControlAffinity.trailing,
              title: Text(username, style: popValue(fontSize: 16)),
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
          ),
        );
      },
    );
  }
}
