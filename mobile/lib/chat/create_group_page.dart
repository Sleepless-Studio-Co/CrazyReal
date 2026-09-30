import 'package:flutter/material.dart';
import '../services/friend_service.dart';
import '../services/chat_service.dart';
import '../services/api_exception.dart';
import '../widgets/feed_avatar.dart';
import '../widgets/paper.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  final TextEditingController _nameController = TextEditingController();

  List<dynamic> _friends = [];
  final List<int> _selectedUserIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _friendService.getFriends();
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoading = false;
        });

        if (_friends.isEmpty) {
          _showNoFriendsDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final message = e is ApiException ? e.message : 'Erreur lors du chargement des amis';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: paperDanger),
        );
      }
    }
  }

  void _showNoFriendsDialog() {
    paperInfo(
      context,
      title: 'Aucun ami',
      message:
          "Tu n'as pas encore d'amis. Ajoute des amis avant de pouvoir créer un groupe.",
      onDismissed: () {
        if (mounted) Navigator.pop(context);
      },
    );
  }

  void _toggleSelection(int userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        if (_selectedUserIds.length < 49) {
          _selectedUserIds.add(userId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Limite de 50 membres atteinte')),
          );
        }
      }
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom requis et au moins 1 ami sélectionné')),
      );
      return;
    }

    try {
      await _chatService.createGroup(name, _selectedUserIds);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Groupe créé !'), backgroundColor: paperSuccess),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.message : 'Erreur lors de la création du groupe';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: paperDanger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paperBg,
      appBar: paperAppBar(title: 'Nouveau groupe'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _nameController,
              style: paperValue(),
              textInputAction: TextInputAction.done,
              decoration: paperInputDecoration(
                label: 'Nom du groupe',
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                header: true,
                child: Text(
                  'MEMBRES — ${_selectedUserIds.length} SÉLECTIONNÉ(S)',
                  style: paperLabel(),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: paperAccent),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _friends.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final friend = _friends[index] as Map<String, dynamic>;
                      final username = friend['username']?.toString() ?? '';
                      final isSelected =
                          _selectedUserIds.contains(friend['id']);

                      return Container(
                        decoration: paperCardDecoration(
                          border: isSelected ? paperAccent : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(friend['id']),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Action principale : un vrai bouton libellé plutôt qu'une icône
          // isolée dans l'AppBar.
          Container(
            decoration: const BoxDecoration(
              color: paperCard,
              border: Border(top: BorderSide(color: paperBorder)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text('Créer le groupe (${_selectedUserIds.length})'),
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
          ),
        ],
      ),
    );
  }
}
