import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/chat_service.dart';

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
  late IO.Socket _socket; // Déclaration du WebSocket

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _initSocket(); // On lance la connexion
  }

  @override
  void dispose() {
    // On ferme proprement le tunnel quand on quitte la page
    _socket.disconnect();
    _socket.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // 1. Chargement classique de l'historique
  Future<void> _loadInitialMessages() async {
    final msgs = await _chatService.getMessages(widget.conversationId);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
    }
  }

  // 2. Configuration du WebSocket
  void _initSocket() {
    final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

    _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket']) // On force le mode WebSocket
        .disableAutoConnect()
        .build());

    _socket.connect();

    _socket.onConnect((_) {
      // Dès qu'on est connecté, on rejoint le salon de cette conversation
      _socket.emit('joinRoom', widget.conversationId);
    });

    // On écoute les nouveaux messages entrants
    _socket.on('newMessage', (data) {
      if (mounted) {
        setState(() {
          _messages.add(data); // On ajoute le message reçu à la liste
        });
      }
    });
  }

  // 3. Envoi du message via notre route HTTP classique
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear(); 
    
    final success = await _chatService.sendMessage(widget.conversationId, text);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur d\'envoi'), backgroundColor: Colors.red),
      );
    }
    // Pas besoin de recharger la liste ici, le message va nous revenir via le WebSocket !
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