import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/call_notification_payload.dart';
import '../../firebase_options.dart';
import '../constants/app_constants.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Android background/terminated notifications should be displayed by FCM
  // using the backend-provided high-priority notification payload.
}

class NotificationService {
  NotificationService({
    required FirebaseMessaging messaging,
    required FlutterLocalNotificationsPlugin localNotifications,
  }) : _messaging = messaging,
       _localNotifications = localNotifications;

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final StreamController<CallNotificationPayload> _callEventsController =
      StreamController<CallNotificationPayload>.broadcast();

  bool _isInitialized = false;
  CallNotificationPayload? _initialNotificationPayload;

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
  Stream<CallNotificationPayload> get onCallEvent =>
      _callEventsController.stream;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    const androidChannel = AndroidNotificationChannel(
      AppConstants.incomingCallNotificationChannelId,
      AppConstants.incomingCallNotificationChannelName,
      description: AppConstants.incomingCallNotificationChannelDescription,
      importance: Importance.max,
    );

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          return;
        }

        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        _emitCallEvent(CallNotificationPayload.fromMap(decoded));
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _initialNotificationPayload = _parseCallPayload(initialMessage.data);
      if (_initialNotificationPayload != null) {
        _emitCallEvent(_initialNotificationPayload!);
      }
    }

    _isInitialized = true;
  }

  Future<CallNotificationPayload?> getInitialNotificationPayload() async {
    await initialize();
    return _initialNotificationPayload;
  }

  Future<String?> getFcmToken() async {
    try {
      if (Platform.isIOS) {
        await _messaging.getAPNSToken();
      }
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> showIncomingCallNotification(
    CallNotificationPayload payload,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      AppConstants.incomingCallNotificationChannelId,
      AppConstants.incomingCallNotificationChannelName,
      channelDescription:
          AppConstants.incomingCallNotificationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      ticker: 'Incoming Talkiyo Call',
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentSound: true),
    );

    await _localNotifications.show(
      payload.callId.hashCode,
      payload.callerName,
      'Incoming Talkiyo call',
      notificationDetails,
      payload: jsonEncode(payload.toMap()),
    );
  }

  Future<void> cancelIncomingCallNotification(String callId) async {
    await _localNotifications.cancel(callId.hashCode);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final payload = _parseCallPayload(message.data);
    if (payload == null) {
      return;
    }

    _emitCallEvent(payload);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final payload = _parseCallPayload(message.data);
    if (payload == null) {
      return;
    }

    _emitCallEvent(payload);
  }

  CallNotificationPayload? _parseCallPayload(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return null;
    }

    final payload = CallNotificationPayload.fromMap(data);
    if (payload.callId.isEmpty || payload.channelName.isEmpty) {
      return null;
    }

    return payload;
  }

  void _emitCallEvent(CallNotificationPayload payload) {
    _callEventsController.add(payload);
  }

  Future<void> dispose() async {
    await _callEventsController.close();
  }
}
