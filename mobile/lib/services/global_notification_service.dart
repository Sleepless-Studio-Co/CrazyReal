import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../auth/auth_service.dart';
import '../utils/media_url.dart';

class GlobalNotificationService {
  GlobalNotificationService._internal();
  static final GlobalNotificationService _instance =
      GlobalNotificationService._internal();
  factory GlobalNotificationService() => _instance;

  final AuthService _authService = AuthService();
  io.Socket? _socket;

  Future<void> connect() async {
    if (_socket != null) return;

    final token = await _authService.getAccessToken();
    if (token == null) return;

    // Use a decoded token to get userId if possible, or just send token
    // For this implementation, we'll assume the backend gets the user from the token.
    _socket = io.io(
      '$apiBaseUrl/notifications',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) => debugPrint('[notif-socket] connected'));

    _socket!.on('friendRequestReceived', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        final username = map['requesterUsername'] as String;

        debugPrint('[notif-socket] friend request from $username');
      } catch (e) {
        debugPrint('[notif-socket] error parsing friendRequestReceived: $e');
      }
    });

    _socket!.on('challengeCreated', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        final title = map['challengeTitle']?.toString() ?? '';
        debugPrint('[notif-socket] challenge created: $title');
      } catch (e) {
        debugPrint('[notif-socket] error parsing challengeCreated: $e');
      }
    });

    _socket!.on('challengeReminder', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        final title = map['challengeTitle']?.toString() ?? '';
        final hours = map['hoursRemaining'] as int? ?? 0;
        debugPrint('[notif-socket] challenge reminder: $title ($hours h)');
      } catch (e) {
        debugPrint('[notif-socket] error parsing challengeReminder: $e');
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
