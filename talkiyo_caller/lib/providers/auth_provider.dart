import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/services/firestore_service.dart';
import '../core/services/notification_service.dart';
import '../models/app_user.dart';

class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  AuthProvider({
    required FirebaseAuth firebaseAuth,
    required FirestoreService firestoreService,
    required NotificationService notificationService,
  }) : _firebaseAuth = firebaseAuth,
       _firestoreService = firestoreService,
       _notificationService = notificationService;

  final FirebaseAuth _firebaseAuth;
  final FirestoreService _firestoreService;
  final NotificationService _notificationService;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;

  User? _firebaseUser;
  AppUser? _appUser;
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _hasInitialized = false;
  String? _errorMessage;

  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _firebaseUser != null;

  Future<void> initialize() async {
    if (_hasInitialized) {
      return;
    }

    _hasInitialized = true;
    WidgetsBinding.instance.addObserver(this);

    _authSubscription = _firebaseAuth.authStateChanges().listen((user) {
      unawaited(_handleAuthStateChanged(user));
    });

    _tokenSubscription = _notificationService.onTokenRefresh.listen((token) {
      final currentUser = _firebaseUser;
      if (currentUser == null) {
        return;
      }

      unawaited(_updateFcmTokenSafely(currentUser.uid, token));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeNotifications());
    });
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
    } catch (_) {
      _errorMessage = 'Notifications are unavailable right now.';
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user?.updateDisplayName(name.trim());
      await _syncCurrentUser(
        preferredName: name.trim(),
        preferredPhoneNumber: phoneNumber.trim(),
      );
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _mapAuthError(error);
      return false;
    } catch (_) {
      _errorMessage = 'Unable to create your account right now.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _syncCurrentUser();
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _mapAuthError(error);
      return false;
    } catch (_) {
      _errorMessage = 'Unable to log in right now.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    final currentUser = _firebaseUser;
    _setLoading(true);

    try {
      if (currentUser != null) {
        await _firestoreService.updateUserOnlineStatus(
          uid: currentUser.uid,
          isOnline: false,
        );
      }
      await _firebaseAuth.signOut();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    _firebaseUser = user;

    if (user == null) {
      _appUser = null;
      _isInitializing = false;
      notifyListeners();
      return;
    }

    try {
      await _syncCurrentUser();
    } on FirebaseException catch (error) {
      _errorMessage = _mapFirestoreError(error);
    } catch (_) {
      _errorMessage = 'Unable to sync your caller profile right now.';
    }

    _isInitializing = false;
    notifyListeners();
  }

  Future<void> _syncCurrentUser({
    String? preferredName,
    String? preferredPhoneNumber,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return;
    }

    final token = await _notificationService.getFcmToken() ?? '';
    final resolvedPhoneNumber = preferredPhoneNumber?.trim().isNotEmpty == true
        ? preferredPhoneNumber!.trim()
        : _appUser?.phoneNumber ?? '';
    _appUser = await _firestoreService.upsertCallerUser(
      uid: user.uid,
      email: user.email ?? '',
      name: preferredName ?? user.displayName ?? _appUser?.name ?? '',
      phoneNumber: resolvedPhoneNumber,
      isOnline: true,
      fcmToken: token,
    );
    notifyListeners();
  }

  Future<void> _updateFcmTokenSafely(String uid, String token) async {
    try {
      await _firestoreService.updateUserFcmToken(uid: uid, fcmToken: token);
    } on FirebaseException catch (error) {
      _errorMessage = _mapFirestoreError(error);
      notifyListeners();
    }
  }

  Future<void> _setPresence(bool isOnline) async {
    final user = _firebaseUser;
    if (user == null) {
      return;
    }

    try {
      await _firestoreService.updateUserOnlineStatus(
        uid: user.uid,
        isOnline: isOnline,
      );
      _appUser = _appUser?.copyWith(
        isOnline: isOnline,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    } on FirebaseException catch (error) {
      _errorMessage = _mapFirestoreError(error);
      notifyListeners();
    }
  }

  String _mapFirestoreError(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'Firestore rules are blocking caller access. Update your Firestore security rules for users and calls.';
    }

    return error.message ?? 'A Firestore error occurred.';
  }

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again shortly.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_firebaseUser == null) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_syncCurrentUser());
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_setPresence(false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.dispose();
  }
}
