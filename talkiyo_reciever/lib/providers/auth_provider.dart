import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthService authService}) : _authService = authService;

  final AuthService _authService;

  StreamSubscription<User?>? _authSubscription;
  User? _user;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void initialize() {
    _user = _authService.currentUser;
    _authSubscription ??= _authService.authStateChanges().listen(
      (firebaseUser) {
        _user = firebaseUser;
        _isInitialized = true;
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage = 'Unable to read authentication state.';
        _isInitialized = true;
        notifyListeners();
      },
    );
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.signUp(
        email: email.trim(),
        password: password.trim(),
        name: name.trim(),
      );
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _mapFirebaseAuthError(error);
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Unable to create your account right now.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.login(email: email.trim(), password: password.trim());
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _mapFirebaseAuthError(error);
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Unable to sign in right now.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.logout();
    } on FirebaseAuthException catch (error) {
      _errorMessage = _mapFirebaseAuthError(error);
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Unable to log out right now.';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'That email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
