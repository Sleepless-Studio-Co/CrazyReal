import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../auth/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/media_url.dart';
import 'notification_service.dart';
import '../main.dart';

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
        final username = map['requesterUsername'] as String;

        final context = navigatorKey.currentContext;
        String title = 'Demande d\'ami';
        String body = '$username vous a envoyé une demande d\'ami';

        if (context != null) {
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            title = l10n.notificationFriendRequestTitle;
            body = l10n.notificationFriendRequestBody(username);
          }
        }

        NotificationService().showNotification(
          title: title,
          body: body,
          channelId: 'friend_requests',
        );
      } catch (e) {
        debugPrint('[notif-socket] error parsing friendRequestReceived: $e');
      }
    });

    _socket!.on('challengeCreated', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        final title = map['challengeTitle']?.toString() ?? '';
        final context = navigatorKey.currentContext;
        var notificationTitle = 'Nouveau défi';
        var body = title;
        if (context != null) {
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            notificationTitle = l10n.notificationChallengeCreatedTitle;
            body = l10n.notificationChallengeCreatedBody(title);
          }
        }
        NotificationService().showNotification(
          id: _notificationId(map['challengeId'], 100000),
          title: notificationTitle,
          body: body,
          channelId: 'challenges',
        );
      } catch (e) {
        debugPrint('[notif-socket] error parsing challengeCreated: $e');
      }
    });

    _socket!.on('challengeReminder', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        final title = map['challengeTitle']?.toString() ?? '';
        final hours = map['hoursRemaining'] as int? ?? 0;
        final context = navigatorKey.currentContext;
        var notificationTitle = 'Défi bientôt terminé';
        var body = '$title : plus que $hours h restantes';
        if (context != null) {
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            notificationTitle = l10n.notificationChallengeReminderTitle;
            body = l10n.notificationChallengeReminderBody(hours, title);
          }
        }
        NotificationService().showNotification(
          id: _notificationId(
              map['challengeId'], hours == 24 ? 200000 : 300000),
          title: notificationTitle,
          body: body,
          channelId: 'challenges',
        );
      } catch (e) {
        debugPrint('[notif-socket] error parsing challengeReminder: $e');
      }
    });

    _socket!.connect();
  }

  int _notificationId(dynamic challengeId, int offset) {
    return offset +
        (challengeId is int
            ? challengeId
            : challengeId.hashCode.abs() % 100000);
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
