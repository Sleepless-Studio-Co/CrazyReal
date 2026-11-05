import 'package:flutter/material.dart';
import '../services/friend_service.dart';
import '../services/chat_service.dart';
import '../services/api_exception.dart';
import '../widgets/feed_avatar.dart';
import '../widgets/sticker_pop.dart';

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
          SnackBar(content: Text(message), backgroundColor: popCoral),
        );
      }
    }
  }

  void _showNoFriendsDialog() {
    popInfo(
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
          const SnackBar(content: Text('Groupe créé !'), backgroundColor: popGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.message : 'Erreur lors de la création du groupe';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: popCoral),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: popAppBar(title: 'Nouveau groupe'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _nameController,
              style: popValue(),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Nom du groupe',
                prefixIcon: Icon(Icons.badge_outlined),
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
                  style: popLabel(),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _friends.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final friend = _friends[index] as Map<String, dynamic>;
                      final username = friend['username']?.toString() ?? '';
                      final isSelected =
                          _selectedUserIds.contains(friend['id']);

                      // Selected friends are lifted, like a pressed-out sticker.
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: popCardDecoration(
                          color: isSelected ? popYellow : popCard,
                          radius: 18,
                          shadow: isSelected ? 4 : 0,
                        ),
                        clipBehavior: Clip.antiAlias,
                        // Transparent material so the tile's ink shows above
                        // the card colour.
                        child: Material(
                          type: MaterialType.transparency,
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(friend['id']),
                            controlAffinity: ListTileControlAffinity.trailing,
                            title:
                                Text(username, style: popValue(fontSize: 16)),
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
                        ),
                      );
                    },
                  ),
          ),
          // Action principale : un vrai bouton libellé plutôt qu'une icône
          // isolée dans l'AppBar.
          Container(
            decoration: const BoxDecoration(
              color: popCard,
              border: Border(top: BorderSide(color: popInk, width: popStroke)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SafeArea(
              top: false,
              child: PopButton(
                onPressed: _submit,
                icon: Icons.group_add_outlined,
                label: 'Créer le groupe (${_selectedUserIds.length})',
                expand: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
