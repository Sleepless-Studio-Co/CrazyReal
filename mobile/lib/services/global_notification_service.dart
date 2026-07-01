import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../auth/auth_service.dart';
import '../utils/media_url.dart';
import 'notification_service.dart';

class GlobalNotificationService {
  GlobalNotificationService._internal();
  static final GlobalNotificationService _instance =
      GlobalNotificationService._internal();
  factory GlobalNotificationService() => _instance;

  final AuthService _authService = AuthService();
  IO.Socket? _socket;

  Future<void> connect() async {
    if (_socket != null) return;

    final token = await _authService.getAccessToken();
    if (token == null) return;

    // Use a decoded token to get userId if possible, or just send token
    // For this implementation, we'll assume the backend gets the user from the token.
    _socket = IO.io(
      '$apiBaseUrl/notifications',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) => debugPrint('[notif-socket] connected'));

    _socket!.on('friendRequestReceived', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        NotificationService().showNotification(
          title: 'Demande d\'ami',
          body: '${map['requesterUsername']} vous a envoyé une demande d\'ami',
          channelId: 'friend_requests',
        );
      } catch (e) {
        debugPrint('[notif-socket] error parsing friendRequestReceived: $e');
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
