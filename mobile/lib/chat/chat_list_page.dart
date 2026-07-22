import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';
import '../services/api_exception.dart';
import 'chat_room_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final ChatSocketService _chatSocket = ChatSocketService();

  List<dynamic> _conversations = [];
  bool _isLoading = true;

  int? _currentUserId;

  // Conversation actuellement ouverte (pour ne pas la marquer non-lue).
  int? _openConversationId;

  // État temps réel, indexé par conversationId.
  final Map<int, int> _unread = {};
  final Map<int, String> _lastPreview = {};

  StreamSubscription<Map<String, dynamic>>? _messageSub;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadConversations();
    _chatSocket.connect();
    _messageSub = _chatSocket.messages.listen(_onSocketMessage);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getUser();
    if (mounted && user != null) {
      setState(() => _currentUserId = user['id'] as int?);
    }
  }

  void _onSocketMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    final convId = msg['conversationId'] as int?;
    if (convId == null) return;

    // Une conversation inconnue de la liste (nouvellement créée) : on recharge.
    final idx = _conversations.indexWhere((c) => c['id'] == convId);
    if (idx == -1) {
      _loadConversations();
      return;
    }

    final senderId = (msg['sender'] as Map?)?['id'] as int?;
    final isOwn = senderId != null && senderId == _currentUserId;

    setState(() {
      _lastPreview[convId] = (msg['content'] as String?) ?? '';
      // Pas de badge pour ses propres messages ni pour la conversation ouverte.
      if (!isOwn && convId != _openConversationId) {
        _unread[convId] = (_unread[convId] ?? 0) + 1;
      }
      // Remonter la conversation en tête de liste.
      final conv = _conversations.removeAt(idx);
      _conversations.insert(0, conv);
    });
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

  Future<void> _openConversation(dynamic conv, String name, bool isGroup) async {
    final convId = conv['id'] as int;
    setState(() {
      _openConversationId = convId;
      _unread.remove(convId);
    });
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomPage(
          conversationId: convId,
          conversationName: name,
          isGroup: isGroup,
        ),
      ),
    );
    _openConversationId = null;
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
                        final convId = conv['id'] as int;
                        final isGroup = conv['isGroup'] == true;
                        final name = conv['name'] ?? 'Discussion privée';

                        final participants = conv['participants'] as List;
                        final participantCount = participants.length;

                        final preview = _lastPreview[convId];
                        final unread = _unread[convId] ?? 0;
                        final hasUnread = unread > 0;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isGroup ? Colors.blue : Colors.grey,
                            child: Icon(isGroup ? Icons.group : Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            preview ?? '$participantCount membre(s)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                              color: hasUnread ? Colors.black87 : Colors.grey[600],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasUnread)
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                  child: Text(
                                    '$unread',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              if (isGroup)
                                IconButton(
                                  icon: const Icon(Icons.exit_to_app, color: Colors.red),
                                  tooltip: 'Quitter le groupe',
                                  onPressed: () => _leaveGroup(convId),
                                ),
                            ],
                          ),
                          onTap: () => _openConversation(conv, name, isGroup),
                        );
                      },
                    ),
            ),
    );
  }
}
