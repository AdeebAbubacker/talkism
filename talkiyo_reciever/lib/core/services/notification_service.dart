import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/app_constants.dart';

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotificationsPlugin,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotificationsPlugin =
           localNotificationsPlugin ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin;
  final StreamController<Map<String, dynamic>> _callPayloadController =
      StreamController<Map<String, dynamic>>.broadcast();

  Map<String, dynamic>? _initialPayload;
  bool _initialized = false;

  Stream<Map<String, dynamic>> get callPayloadStream =>
      _callPayloadController.stream;

  Stream<String> get tokenRefreshStream => _messaging.onTokenRefresh;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _requestPermissions();
    await _initializeLocalNotifications();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null && isIncomingCallPayload(initialMessage.data)) {
      _initialPayload = Map<String, dynamic>.from(initialMessage.data);
    }

    _initialized = true;
  }

  Future<NotificationSettings> _requestPermissions() {
    return _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<void> _initializeLocalNotifications() async {
    const androidInitializationSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosInitializationSettings = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          return;
        }

        final decodedPayload = jsonDecode(payload);
        if (decodedPayload is Map<String, dynamic>) {
          _callPayloadController.add(decodedPayload);
        } else if (decodedPayload is Map) {
          _callPayloadController.add(
            decodedPayload.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      },
    );

    if (kIsWeb) {
      return;
    }

    const androidChannel = AndroidNotificationChannel(
      AppConstants.incomingCallChannelId,
      AppConstants.incomingCallChannelName,
      description: AppConstants.incomingCallChannelDescription,
      importance: Importance.max,
      playSound: true,
    );

    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(androidChannel);
  }

  Future<String?> getToken() => _messaging.getToken();

  Map<String, dynamic>? takeInitialPayload() {
    final payload = _initialPayload;
    _initialPayload = null;
    return payload;
  }

  bool isIncomingCallPayload(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase();
    final notificationType = data['notificationType']?.toString().toLowerCase();

    return data.containsKey('callId') ||
        type == 'incoming_call' ||
        notificationType == 'incoming_call';
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (!isIncomingCallPayload(message.data)) {
      return;
    }

    _callPayloadController.add(Map<String, dynamic>.from(message.data));

    unawaited(showIncomingCallNotification(message));
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    if (!isIncomingCallPayload(message.data)) {
      return;
    }

    _callPayloadController.add(Map<String, dynamic>.from(message.data));
  }

  Future<void> showIncomingCallNotification(RemoteMessage message) async {
    if (kIsWeb) {
      return;
    }

    final callerName =
        message.data['callerName']?.toString() ??
        message.notification?.title ??
        'Incoming call';
    final callType =
        message.data['callType']?.toString().toLowerCase() ?? 'audio';

    const androidDetails = AndroidNotificationDetails(
      AppConstants.incomingCallChannelId,
      AppConstants.incomingCallChannelName,
      channelDescription: AppConstants.incomingCallChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      playSound: true,
      ticker: 'Incoming call',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotificationsPlugin.show(
      message.hashCode,
      callerName,
      'Incoming $callType call',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> dispose() async {
    await _callPayloadController.close();
  }
}
