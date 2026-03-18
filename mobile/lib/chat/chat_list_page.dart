import 'package:flutter/material.dart';
import '../services/chat_service.dart';
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
    final convos = await _chatService.getConversations();
    if (mounted) {
      setState(() {
        _conversations = convos;
        _isLoading = false;
      });
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
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatRoomPage(
                                  conversationId: conv['id'],
                                  conversationName: name,
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