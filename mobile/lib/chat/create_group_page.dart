import 'package:flutter/material.dart';
import '../services/friend_service.dart';
import '../services/chat_service.dart';

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

  Future<void> _loadFriends() async {
    final friends = await _friendService.getFriends();
    setState(() {
      _friends = friends;
      _isLoading = false;
    });
  }

  void _toggleSelection(int userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        if (_selectedUserIds.length < 49) { // 49 + créateur = 50 max
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
    if (name.isEmpty || _selectedUserIds.length < 1) { // 1 ami min + moi = 2
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom requis et au moins 1 ami sélectionné')),
      );
      return;
    }

    final success = await _chatService.createGroup(name, _selectedUserIds);
    if (mounted && success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Groupe créé !'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau Groupe'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _submit)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du groupe',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friend = _friends[index];
                      final isSelected = _selectedUserIds.contains(friend['id']);
                      return CheckboxListTile(
                        title: Text(friend['username']),
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(friend['id']),
                        secondary: const CircleAvatar(child: Icon(Icons.person)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}