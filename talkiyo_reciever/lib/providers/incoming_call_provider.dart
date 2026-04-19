import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/call_model.dart';
import '../services/auth_service.dart';
import '../services/agora_service.dart';

/// Provider for listening to incoming calls
class IncomingCallProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final AgoraService _agoraService;

  CallModel? _incomingCall;
  bool _isListening = false;

  IncomingCallProvider({
    required FirestoreService firestoreService,
    required AuthService authService,
    required AgoraService agoraService,
  })  : _firestoreService = firestoreService,
        _authService = authService,
        _agoraService = agoraService;

  CallModel? get incomingCall => _incomingCall;
  bool get isListening => _isListening;

  /// Start listening for incoming calls
  void startListening() {
    if (_isListening || _authService.currentUserId == null) return;

    _isListening = true;

    _firestoreService
        .streamIncomingCall(_authService.currentUserId!)
        .listen((call) {
      if (call != null && call.status == CallStatus.ringing) {
        _incomingCall = call;
        notifyListeners();
      }
    });
  }

  /// Stop listening for incoming calls
  void stopListening() {
    _isListening = false;
    _incomingCall = null;
  }

  /// Clear current incoming call
  void clearIncomingCall() {
    _incomingCall = null;
    notifyListeners();
  }
}
