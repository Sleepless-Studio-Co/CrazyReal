import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/chat_service.dart';
import '../services/api_exception.dart';

class ChatRoomPage extends StatefulWidget {
  final int conversationId;
  final String conversationName;

  const ChatRoomPage({
    super.key,
    required this.conversationId,
    required this.conversationName,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  
  List<dynamic> _messages = [];
  bool _isLoading = true;
  late IO.Socket _socket;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _initSocket();
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
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

  void _initSocket() {
    final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

    _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build());

    _socket.connect();

    _socket.onConnect((_) {
      _socket.emit('joinRoom', widget.conversationId);
    });

    _socket.on('newMessage', (data) {
      if (mounted) {
        setState(() {
          _messages.add(data);
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.conversationName)),
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