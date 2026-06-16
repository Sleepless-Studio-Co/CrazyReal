import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/api_exception.dart';
import 'chat_room_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final convos = await _chatService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = convos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final message = e is ApiException ? e.message : 'Erreur lors du chargement des discussions';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _leaveGroup(int conversationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: const Text('Veux-tu vraiment quitter ce groupe ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Quitter')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _chatService.leaveGroup(conversationId);
      _loadConversations();
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.message : 'Erreur lors de la sortie du groupe';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Messages'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadConversations,
              child: _conversations.isEmpty
                  ? ListView(
                      children: const [
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text("Aucune discussion pour le moment."),
                          ),
                        )
                      ],
                    )
                  : ListView.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conv = _conversations[index];
                        final isGroup = conv['isGroup'] == true;
                        final name = conv['name'] ?? 'Discussion privée';
                        
                        final participants = conv['participants'] as List;
                        final participantCount = participants.length;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isGroup ? Colors.blue : Colors.grey,
                            child: Icon(isGroup ? Icons.group : Icons.person, color: Colors.white),
                          ),
                          title: Text(name),
                          subtitle: Text('$participantCount membre(s)'),
                          trailing: isGroup
                              ? IconButton(
                                  icon: const Icon(Icons.exit_to_app, color: Colors.red),
                                  tooltip: 'Quitter le groupe',
                                  onPressed: () => _leaveGroup(conv['id']),
                                )
                              : null,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatRoomPage(
                                  conversationId: conv['id'],
                                  conversationName: name,
                                  isGroup: isGroup,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
    );
  }
}