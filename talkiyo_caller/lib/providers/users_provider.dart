import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/services/firestore_service.dart';
import '../models/app_user.dart';

class UsersProvider extends ChangeNotifier {
  UsersProvider({required FirestoreService firestoreService})
    : _firestoreService = firestoreService;

  final FirestoreService _firestoreService;

  StreamSubscription<List<AppUser>>? _usersSubscription;
  String? _currentUserId;

  List<AppUser> _receivers = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AppUser> get receivers => _receivers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void bindCurrentUser(String? userId) {
    if (_currentUserId == userId) {
      return;
    }

    _currentUserId = userId;
    if (userId == null || userId.isEmpty) {
      _usersSubscription?.cancel();
      _receivers = const [];
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    startListening(userId);
  }

  void startListening(String currentUserId) {
    _isLoading = true;
    notifyListeners();

    _usersSubscription?.cancel();
    _usersSubscription = _firestoreService
        .streamAvailableUsers(currentUserId: currentUserId)
        .listen(
          (users) {
            _receivers = users;
            _errorMessage = null;
            _isLoading = false;
            notifyListeners();
          },
          onError: (Object error) {
            if (error is FirebaseException &&
                error.code == 'permission-denied') {
              _errorMessage =
                  'Firestore rules are blocking the Talkiyo user list. Allow authenticated users to read other user profiles.';
            } else {
              _errorMessage = 'Unable to load Talkiyo users.';
            }
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    super.dispose();
  }
}
