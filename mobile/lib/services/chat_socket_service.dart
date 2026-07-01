import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../auth/auth_service.dart';
import '../utils/media_url.dart';
import 'notification_service.dart';

/// Socket temps réel unique et persistant pour tout le chat.
///
/// Contrairement à l'ancienne approche (un socket par `ChatRoomPage`), ce
/// service vit au niveau de l'application : il se connecte après le login et
/// reste connecté tant que l'utilisateur est authentifié. Le backend fait
/// rejoindre automatiquement toutes les conversations de l'utilisateur à la
/// connexion, donc les `newMessage` arrivent même quand aucune conversation
/// n'est ouverte (liste, badges).
///
/// Les écrans s'abonnent aux flux `messages` / `typingEvents` et filtrent
/// eux-mêmes par `conversationId`.
class ChatSocketService {
  ChatSocketService._internal();
  static final ChatSocketService _instance = ChatSocketService._internal();
  factory ChatSocketService() => _instance;

  final AuthService _authService = AuthService();

  IO.Socket? _socket;
  bool _connecting = false;

  final _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _typingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  /// Chaque message reçu (`newMessage`). Contient au moins `id`, `content`,
  /// `conversationId`, `createdAt` et `sender { id, username }`.
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Événements de frappe. Forme : `{ conversationId, userId, username, typing }`.
  Stream<Map<String, dynamic>> get typingEvents => _typingController.stream;

  /// `true` quand le socket est connecté, `false` sinon.
  Stream<bool> get connectionState => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Établit la connexion si elle n'existe pas déjà. Sans effet si déjà
  /// connecté/en cours, ou si aucun token n'est disponible.
  Future<void> connect() async {
    if (_socket != null || _connecting) return;
    _connecting = true;

    final token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      _connecting = false;
      return;
    }

    // websocket-only : la bascule polling→websocket provoquait des coupures
    // (mêmes réglages que le socket du feed, qui est stable).
    final socket = IO.io(
      '$apiBaseUrl/chat',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(999)
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      debugPrint('[chat-socket] connecté id=${socket.id}');
      _connectionController.add(true);
    });
    socket.onDisconnect((reason) {
      debugPrint('[chat-socket] déconnecté: $reason');
      _connectionController.add(false);
    });
    socket.onConnectError((err) {
      debugPrint('[chat-socket] connect_error: $err');
      _connectionController.add(false);
    });
    socket.onError((err) => debugPrint('[chat-socket] error: $err'));

    socket.on('newMessage', (data) {
      debugPrint('[chat-socket] newMessage reçu: $data');
      try {
        final map = Map<String, dynamic>.from(data as Map);
        _messageController.add(map);

        // Show local notification
        NotificationService().showNotification(
          title: 'Nouveau message de ${map['sender']['username']}',
          body: map['content'],
          channelId: 'general',
        );
      } catch (e) {
        debugPrint('[chat-socket] newMessage parse error: $e');
      }
    });

    socket.on('userTyping', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        _typingController.add({...map, 'typing': true});
      } catch (_) {}
    });

    socket.on('userStoppedTyping', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        _typingController.add({...map, 'typing': false});
      } catch (_) {}
    });

    socket.connect();
    _connecting = false;
  }

  /// Rejoint explicitement une conversation. Utile pour les conversations
  /// créées après l'établissement de la connexion (l'auto-join côté serveur ne
  /// couvre que celles existantes au moment du connect).
  void joinRoom(int conversationId) =>
      _socket?.emit('joinRoom', conversationId);

  void emitTyping(int conversationId) =>
      _socket?.emit('typing', conversationId);

  void emitStopTyping(int conversationId) =>
      _socket?.emit('stopTyping', conversationId);

  /// Ferme la connexion (à appeler au logout).
  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connecting = false;
    _connectionController.add(false);
  }
}
