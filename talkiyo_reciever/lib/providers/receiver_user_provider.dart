import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../core/services/firestore_service.dart';
import '../core/services/notification_service.dart';
import '../models/app_user.dart';

class ReceiverUserProvider extends ChangeNotifier with WidgetsBindingObserver {
  ReceiverUserProvider({
    required FirestoreService firestoreService,
    required NotificationService notificationService,
  }) : _firestoreService = firestoreService,
       _notificationService = notificationService;

  final FirestoreService _firestoreService;
  final NotificationService _notificationService;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<AppUser?>? _profileSubscription;
  User? _authUser;
  AppUser? _appUser;
  bool _isSyncing = false;
  String? _errorMessage;
  bool _initialized = false;

  AppUser? get appUser => _appUser;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;

  void initialize() {
    if (_initialized) {
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    _tokenRefreshSubscription = _notificationService.tokenRefreshStream.listen((
      token,
    ) {
      final uid = _authUser?.uid;
      if (uid == null) {
        return;
      }
      unawaited(_firestoreService.updateUserFcmToken(uid, token));
    });

    _initialized = true;
  }

  void attachAuthUser(User? user) {
    if (_authUser?.uid == user?.uid) {
      return;
    }

    final previousUid = _authUser?.uid;
    _authUser = user;

    if (previousUid != null && previousUid != user?.uid) {
      unawaited(_firestoreService.updateUserOnlineStatus(previousUid, false));
    }

    _profileSubscription?.cancel();
    _profileSubscription = null;
    _appUser = null;
    notifyListeners();

    if (user == null) {
      return;
    }

    _profileSubscription = _firestoreService
        .watchUser(user.uid)
        .listen(
          (profile) {
            _appUser = profile;
            notifyListeners();
          },
          onError: (_) {
            _errorMessage = 'Unable to load receiver profile.';
            notifyListeners();
          },
        );

    unawaited(syncCurrentUser());
  }

  Future<void> syncCurrentUser() async {
    final user = _authUser;
    if (user == null) {
      return;
    }

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fcmToken = await _notificationService.getToken();
      await _firestoreService.createOrUpdateReceiverUser(
        firebaseUser: user,
        name: user.displayName,
        fcmToken: fcmToken,
        isOnline: true,
      );
    } catch (_) {
      _errorMessage = 'Unable to sync your receiver profile.';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = _authUser?.uid;
    if (uid == null) {
      return;
    }

    final isOnline = state == AppLifecycleState.resumed;
    unawaited(_firestoreService.updateUserOnlineStatus(uid, isOnline));
  }

  @override
  void dispose() {
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _tokenRefreshSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
