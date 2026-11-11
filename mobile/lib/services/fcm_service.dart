import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../main.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      return;
    }
  }
  // Notification payloads are displayed by FCM while the app is backgrounded.
  // Data-only messages still need a local notification.
  if (message.notification == null) {
    await NotificationService().init();
    await _showRemoteMessage(message);
  }
}

Future<void> _showRemoteMessage(RemoteMessage message) async {
  final notification = message.notification;
  final title = notification?.title ?? message.data['title']?.toString();
  final body = notification?.body ?? message.data['body']?.toString();
  if (title == null || body == null) return;
  await NotificationService().showNotification(
    id: message.hashCode,
    title: title,
    body: body,
    channelId: message.data['channelId']?.toString() ?? 'general',
  );
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final AuthService _authService = AuthService();
  RemoteMessage? _pendingInitialMessage;
  bool _isRegistered = false;
  bool _isAvailable = false;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  Future<void> init() async {
    if (Firebase.apps.isEmpty) return;
    _isAvailable = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_showRemoteMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    _pendingInitialMessage = await _messaging.getInitialMessage();
    _messaging.onTokenRefresh.listen((token) async {
      if (_isRegistered) await _registerToken(token);
    });
  }

  Future<void> registerForUser() async {
    if (!_isAvailable) return;
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    if (token != null) await _registerToken(token);
    await _messaging.subscribeToTopic('global');
    _isRegistered = true;
  }

  Future<void> unregister() async {
    if (!_isAvailable) return;
    _isRegistered = false;
    final token = await _messaging.getToken();
    if (token != null) await _authService.deleteDeviceToken(token);
    await _messaging.unsubscribeFromTopic('global');
  }

  Future<void> _registerToken(String token) async {
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    await _authService.registerDeviceToken(token, platform);
  }

  void handlePendingNavigation() {
    final message = _pendingInitialMessage;
    _pendingInitialMessage = null;
    if (message != null) _handleOpenedMessage(message);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    NotificationService().handlePushNavigation(message.data);
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }
}
