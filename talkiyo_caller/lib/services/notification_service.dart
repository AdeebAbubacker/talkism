import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await NotificationService.showIncomingCallNotification(message);
}

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final StreamController<String> _callTapController =
      StreamController<String>.broadcast();

  static const AndroidNotificationChannel _incomingCallsChannel =
      AndroidNotificationChannel(
        'talkiyo_incoming_calls',
        'Incoming calls',
        description: 'Incoming Talkiyo call notifications',
        importance: Importance.max,
        playSound: true,
      );

  static bool _localNotificationsReady = false;
  static String? _pendingCallId;
  static StreamSubscription<String>? _tokenRefreshSub;

  static Stream<String> get callTapStream => _callTapController.stream;

  static Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    await _ensureLocalNotificationsInitialized();

    FirebaseMessaging.onMessage.listen(showIncomingCallNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_emitCallTapFromMessage);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _emitCallTapFromMessage(initialMessage);
    }

    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        response?.payload != null) {
      _emitCallTapFromPayload(response!.payload);
    }
  }

  static Future<void> syncTokenForCurrentUser() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _saveToken(token);
    }

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) {
      unawaited(_saveToken(newToken));
    });
  }

  static String? takePendingCallId() {
    final callId = _pendingCallId;
    _pendingCallId = null;
    return callId;
  }

  static Future<void> showIncomingCallNotification(
    RemoteMessage message,
  ) async {
    final callId = _callIdFromData(message.data);
    if (callId == null) return;

    await _ensureLocalNotificationsInitialized();

    final callerName =
        _stringFromData(message.data, 'callerName') ??
        _stringFromData(message.data, 'caller_name') ??
        'Someone';
    final callType =
        _stringFromData(message.data, 'callType') ??
        _stringFromData(message.data, 'call_type') ??
        'audio';
    final title =
        message.notification?.title ??
        _stringFromData(message.data, 'notificationTitle') ??
        'Incoming ${callType == 'video' ? 'video' : 'audio'} call';
    final body =
        message.notification?.body ??
        _stringFromData(message.data, 'notificationBody') ??
        '$callerName is calling you';
    final payload = jsonEncode({'callId': callId});

    const androidDetails = AndroidNotificationDetails(
      'talkiyo_incoming_calls',
      'Incoming calls',
      channelDescription: 'Incoming Talkiyo call notifications',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      enableVibration: true,
      playSound: true,
      ticker: 'Incoming Talkiyo call',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      _notificationIdForCall(callId),
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: darwinDetails),
      payload: payload,
    );
  }

  static Future<void> cancelCallNotification(String callId) {
    return _localNotifications.cancel(_notificationIdForCall(callId));
  }

  static Future<void> _ensureLocalNotificationsInitialized() async {
    if (_localNotificationsReady) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _emitCallTapFromPayload(response.payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_incomingCallsChannel);

    _localNotificationsReady = true;
  }

  static Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static void _emitCallTapFromMessage(RemoteMessage message) {
    final callId = _callIdFromData(message.data);
    if (callId != null) _emitCallTap(callId);
  }

  static void _emitCallTapFromPayload(String? payload) {
    final callId = _callIdFromPayload(payload);
    if (callId != null) _emitCallTap(callId);
  }

  static void _emitCallTap(String callId) {
    _pendingCallId = callId;
    if (!_callTapController.isClosed) {
      _callTapController.add(callId);
    }
  }

  static String? _callIdFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return _callIdFromData(decoded);
      }
    } catch (_) {
      return payload;
    }

    return null;
  }

  static String? _callIdFromData(Map<String, dynamic> data) {
    final callId =
        _stringFromData(data, 'callId') ??
        _stringFromData(data, 'call_id') ??
        _stringFromData(data, 'id');
    if (callId == null || callId.isEmpty) return null;

    final type =
        _stringFromData(data, 'type') ??
        _stringFromData(data, 'notificationType');
    if (type == null || type.isEmpty) return callId;

    const allowedTypes = {'incoming_call', 'call_invite', 'call'};
    return allowedTypes.contains(type) ? callId : null;
  }

  static String? _stringFromData(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    return value.toString();
  }

  static int _notificationIdForCall(String callId) {
    return callId.codeUnits.fold<int>(
      0,
      (value, codeUnit) => (value * 31 + codeUnit) & 0x7fffffff,
    );
  }
}
