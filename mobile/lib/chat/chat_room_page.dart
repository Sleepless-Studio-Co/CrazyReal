import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../auth/auth_service.dart';
import '../services/chat_service.dart';
import '../services/api_exception.dart';
import 'group_members_page.dart';

class ChatRoomPage extends StatefulWidget {
  final int conversationId;
  final String conversationName;
  final bool isGroup;

  const ChatRoomPage({
    super.key,
    required this.conversationId,
    required this.conversationName,
    this.isGroup = false,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  IO.Socket? _socket;

  final Map<int, String> _typingUsers = {};
  final Map<int, Timer> _typingTimeouts = {};
  Timer? _stopTypingDebounce;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _initSocket();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _stopTypingDebounce?.cancel();
    for (final timer in _typingTimeouts.values) {
      timer.cancel();
    }
    _socket?.emit('stopTyping', widget.conversationId);
    _socket?.disconnect();
    _socket?.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    try {
      final msgs = await _chatService.getMessages(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final message = e is ApiException ? e.message : 'Erreur lors du chargement des messages';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _initSocket() async {
    final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
    final token = await _authService.getAccessToken();

    final socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token ?? ''})
        .disableAutoConnect()
        .build());
    _socket = socket;

    socket.connect();

    socket.onConnect((_) {
      socket.emit('joinRoom', widget.conversationId);
    });

    socket.on('joinRoomError', (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connexion temps réel : $error'), backgroundColor: Colors.red),
        );
      }
    });

    socket.on('newMessage', (data) {
      if (mounted) {
        setState(() {
          _messages.add(data);
        });
      }
    });

    socket.on('userTyping', (data) {
      final userId = data['userId'] as int;
      final username = data['username'] as String;
      _typingTimeouts[userId]?.cancel();
      _typingTimeouts[userId] = Timer(const Duration(seconds: 5), () => _clearTypingUser(userId));
      if (mounted) {
        setState(() => _typingUsers[userId] = username);
      }
    });

    socket.on('userStoppedTyping', (data) {
      final userId = data['userId'] as int;
      _clearTypingUser(userId);
    });
  }

  void _clearTypingUser(int userId) {
    _typingTimeouts.remove(userId)?.cancel();
    if (mounted) {
      setState(() => _typingUsers.remove(userId));
    }
  }

  void _onTextChanged() {
    if (_messageController.text.isEmpty) {
      _stopTypingDebounce?.cancel();
      if (_isTyping) {
        _isTyping = false;
        _socket?.emit('stopTyping', widget.conversationId);
      }
      return;
    }

    if (!_isTyping) {
      _isTyping = true;
      _socket?.emit('typing', widget.conversationId);
    }

    _stopTypingDebounce?.cancel();
    _stopTypingDebounce = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      _socket?.emit('stopTyping', widget.conversationId);
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    _stopTypingDebounce?.cancel();
    _isTyping = false;
    _socket?.emit('stopTyping', widget.conversationId);

    try {
      await _chatService.sendMessage(widget.conversationId, text);
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.message : 'Erreur d\'envoi';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _typingIndicatorText() {
    final names = _typingUsers.values.toList();
    if (names.length == 1) {
      return '${names.first} est en train d\'écrire...';
    }
    return '${names.join(', ')} sont en train d\'écrire...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversationName),
        actions: [
          if (widget.isGroup)
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'Membres du groupe',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupMembersPage(conversationId: widget.conversationId),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final senderName = msg['sender']['username'];
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              senderName, 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(msg['content'], style: const TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_typingUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _typingIndicatorText(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Écrire...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}