import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Navigation key to redirect on notification click
  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> init({GlobalKey<NavigatorState>? navKey}) async {
    navigatorKey = navKey;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('logo_app');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationClick(response);
      },
    );

    await _createChannels();
  }

  Future<void> _createChannels() async {
    const AndroidNotificationChannel friendRequestsChannel = AndroidNotificationChannel(
      'friend_requests',
      'Friend Requests',
      description: 'Notifications for new friend requests',
      importance: Importance.max,
    );

    const AndroidNotificationChannel challengesChannel = AndroidNotificationChannel(
      'challenges',
      'Challenges',
      description: 'Notifications for new challenges',
      importance: Importance.max,
    );

    const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
      'general',
      'General Notifications',
      description: 'General application notifications',
      importance: Importance.max,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(friendRequestsChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(challengesChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalChannel);
  }

  void _handleNotificationClick(NotificationResponse response) {
    // Requirements: Open app to its root (Home page)
    // If we're already in the app, navigatorKey can be used to pop until root or navigate to home.
    if (navigatorKey?.currentState != null) {
      // Pop all until we reach the root route
      navigatorKey!.currentState!.popUntil((route) => route.isFirst);
    }
  }

  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? channelId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId ?? 'general',
      'General Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }
}
