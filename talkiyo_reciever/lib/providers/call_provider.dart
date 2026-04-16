import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants/app_constants.dart';
import '../core/services/agora_service.dart';
import '../core/services/agora_token_service.dart';
import '../core/services/firestore_service.dart';
import '../core/services/notification_service.dart';
import '../models/call_model.dart';

enum CallUiState { idle, incoming, active, ended }

class CallProvider extends ChangeNotifier {
  CallProvider({
    required FirestoreService firestoreService,
    required AgoraService agoraService,
    required AgoraTokenService agoraTokenService,
    required NotificationService notificationService,
  }) : _firestoreService = firestoreService,
       _agoraService = agoraService,
       _agoraTokenService = agoraTokenService,
       _notificationService = notificationService;

  final FirestoreService _firestoreService;
  final AgoraService _agoraService;
  final AgoraTokenService _agoraTokenService;
  final NotificationService _notificationService;

  StreamSubscription<CallModel?>? _incomingCallSubscription;
  StreamSubscription<CallModel?>? _currentCallSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  User? _authUser;
  CallModel? _currentCall;
  CallUiState _callState = CallUiState.idle;
  bool _isBusy = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _localUserJoined = false;
  int? _remoteUid;
  String? _errorMessage;
  Map<String, dynamic>? _pendingPayload;

  CallModel? get currentCall => _currentCall;
  CallUiState get callState => _callState;
  bool get isBusy => _isBusy;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get localUserJoined => _localUserJoined;
  int? get remoteUid => _remoteUid;
  String? get errorMessage => _errorMessage;
  RtcEngine? get agoraEngine => _agoraService.engine;

  void initialize() {
    _notificationSubscription ??= _notificationService.callPayloadStream.listen(
      (payload) {
        unawaited(handleNotificationPayload(payload));
      },
    );

    _pendingPayload = _notificationService.takeInitialPayload();
  }

  void attachAuthUser(User? user) {
    if (_authUser?.uid == user?.uid) {
      return;
    }

    _authUser = user;
    _cancelIncomingCallListener();
    unawaited(_clearCurrentCallSubscription());

    if (user == null) {
      unawaited(_resetCallLocally(resetStateToIdle: true));
      return;
    }

    _listenForIncomingCalls(user.uid);

    final payload = _pendingPayload;
    _pendingPayload = null;
    if (payload != null) {
      unawaited(handleNotificationPayload(payload));
    }
  }

  void _listenForIncomingCalls(String uid) {
    _incomingCallSubscription = _firestoreService
        .listenForIncomingCalls(uid)
        .listen(
          (call) {
            if (call == null) {
              return;
            }

            if (_callState == CallUiState.active &&
                _currentCall?.callId != call.callId) {
              return;
            }

            _setIncomingCall(call);
          },
          onError: (_) {
            _errorMessage = 'Unable to listen for incoming calls.';
            notifyListeners();
          },
        );
  }

  Future<void> handleNotificationPayload(Map<String, dynamic> payload) async {
    final authUser = _authUser;
    if (authUser == null) {
      _pendingPayload = payload;
      return;
    }

    final receiverId = payload['receiverId']?.toString();
    if (receiverId != null &&
        receiverId.isNotEmpty &&
        receiverId != authUser.uid) {
      return;
    }

    final callId = payload['callId']?.toString();
    if (callId == null || callId.isEmpty) {
      return;
    }

    try {
      final call = await _firestoreService.fetchCallById(callId);
      if (call == null || call.receiverId != authUser.uid) {
        return;
      }
      if (call.status == CallDocumentStatus.ringing) {
        _setIncomingCall(call);
      }
    } catch (_) {
      _errorMessage = 'Unable to sync the incoming call notification.';
      notifyListeners();
    }
  }

  Future<void> acceptCall() async {
    final call = _currentCall;
    final authUser = _authUser;
    if (_isBusy || call == null || authUser == null) {
      return;
    }

    _setBusy(true);
    _errorMessage = null;
    var didMarkCallAccepted = false;

    try {
      debugPrint(
        'Receiver acceptCall start: callId=${call.callId} '
        'channel=${call.channelName} status=${call.status.value}',
      );
      await _ensureAgoraPermissions(call);
      final resolvedToken = await _resolveAgoraToken(call);
      final acceptedCall =
          await _firestoreService.acceptIncomingCall(
            callId: call.callId,
            // The receiver app does not yet persist a per-installation ID, so
            // use the authenticated receiver UID as a stable acceptance marker.
            deviceId: authUser.uid,
          ) ??
          call;

      if (acceptedCall.status != CallDocumentStatus.accepted &&
          acceptedCall.status != CallDocumentStatus.ringing) {
        throw StateError('Call is no longer available.');
      }

      final joiningCall = acceptedCall.copyWith(
        status: CallDocumentStatus.accepted,
        agoraToken: resolvedToken,
      );

      _moveToActiveCall(joiningCall);
      debugPrint('Receiver marked accepted: callId=${call.callId}');
      didMarkCallAccepted = true;
      await _joinAgora(joiningCall);
    } catch (error) {
      debugPrint(
        'Receiver acceptCall error: callId=${call.callId} error=$error',
      );
      if (didMarkCallAccepted) {
        await _resetCallLocally(resetStateToIdle: true);
        _errorMessage = _mapJoinError(error);
      } else {
        _restoreIncomingCall(call, error: _mapJoinError(error));
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> rejectCall() async {
    final call = _currentCall;
    if (_isBusy || call == null) {
      return;
    }

    _setBusy(true);
    _errorMessage = null;

    try {
      await _firestoreService.updateCallStatus(
        call.callId,
        CallDocumentStatus.rejected.value,
      );
    } catch (_) {
      _errorMessage = 'Unable to reject the call right now.';
    } finally {
      await _markEndedThenReset();
      _setBusy(false);
    }
  }

  Future<void> endCall() async {
    final call = _currentCall;
    if (_isBusy || call == null) {
      return;
    }

    _setBusy(true);
    _errorMessage = null;

    try {
      await _firestoreService.updateCallStatus(
        call.callId,
        CallDocumentStatus.ended.value,
      );
    } catch (_) {
      _errorMessage = 'Unable to update the call end status.';
    } finally {
      await _markEndedThenReset();
      _setBusy(false);
    }
  }

  Future<void> toggleMute() async {
    final nextValue = !_isMuted;
    try {
      await _agoraService.muteLocalAudio(nextValue);
      _isMuted = nextValue;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Unable to update microphone state.';
      notifyListeners();
    }
  }

  Future<void> toggleVideo() async {
    if (!(_currentCall?.isVideoCall ?? false)) {
      return;
    }

    final nextValue = !_isVideoEnabled;
    try {
      await _agoraService.setLocalVideoEnabled(nextValue);
      _isVideoEnabled = nextValue;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Unable to update video state.';
      notifyListeners();
    }
  }

  Future<void> switchCamera() async {
    if (!(_currentCall?.isVideoCall ?? false)) {
      return;
    }

    try {
      await _agoraService.switchCamera();
    } catch (_) {
      _errorMessage = 'Unable to switch the camera.';
      notifyListeners();
    }
  }

  Future<void> _joinAgora(CallModel call) async {
    _isMuted = false;
    _isVideoEnabled = call.isVideoCall;
    _localUserJoined = !call.isVideoCall;
    _remoteUid = null;
    notifyListeners();

    await _agoraService.initialize(
      callbacks: AgoraServiceCallbacks(
        onLocalJoinSuccess: () {
          debugPrint(
            'Receiver local Agora join success: '
            'callId=${_currentCall?.callId} channel=${_currentCall?.channelName}',
          );
          _localUserJoined = true;
          final currentCallId = _currentCall?.callId;
          if (currentCallId != null) {
            unawaited(
              _firestoreService.updateCallStatus(
                currentCallId,
                CallDocumentStatus.connected.value,
              ),
            );
          }
          notifyListeners();
        },
        onRemoteUserJoined: (uid) {
          debugPrint(
            'Receiver remote Agora user joined: '
            'callId=${_currentCall?.callId} remoteUid=$uid',
          );
          _remoteUid = uid;
          notifyListeners();
        },
        onRemoteUserLeft: (uid) {
          debugPrint(
            'Receiver remote Agora user left: '
            'callId=${_currentCall?.callId} remoteUid=$uid',
          );
          if (_remoteUid == uid) {
            _remoteUid = null;
            notifyListeners();
          }
        },
        onError: (message) {
          debugPrint(
            'Receiver Agora error: callId=${_currentCall?.callId} '
            'message="$message"',
          );
          _errorMessage = message;
          notifyListeners();
        },
      ),
    );

    await _watchCurrentCall(call.callId);
    await _agoraService.joinChannel(
      channelName: call.channelName,
      token: await _resolveAgoraToken(call),
      uid: _agoraUidFrom(_authUser?.uid ?? call.receiverId),
      enableVideo: call.isVideoCall,
    );
  }

  Future<String> _resolveAgoraToken(CallModel call) async {
    final liveToken = call.agoraToken?.trim() ?? '';
    if (liveToken.isNotEmpty) {
      return liveToken;
    }

    final authUser = _authUser;
    final participantId = authUser?.uid ?? call.receiverId;
    final serverToken = await _agoraTokenService.fetchRtcToken(
      callId: call.callId,
      channelName: call.channelName,
      appUserId: authUser?.uid ?? call.receiverId,
      participantDeviceId: participantId,
      agoraUid: _agoraUidFrom(participantId),
    );
    if (serverToken.isNotEmpty) {
      return serverToken;
    }

    final debugToken = AppConstants.agoraRtcToken.trim();
    if (kDebugMode && debugToken.isNotEmpty) {
      return debugToken;
    }

    throw StateError(
      'Agora RTC token is required. Set CALL_API_BASE_URL to a token server, '
      'provide AGORA_RTC_TOKEN for this exact channel/UID, or disable App '
      'Certificate in Agora Console for local testing.',
    );
  }

  int _agoraUidFrom(String value) {
    if (value.trim().isEmpty) {
      return 0;
    }
    return value.hashCode.abs() % 1000000000;
  }

  String _mapJoinError(Object error) {
    final message = error.toString();
    if (message.contains('Microphone permission is required')) {
      return 'Microphone permission is required to answer the call.';
    }
    if (message.contains('Camera permission is required')) {
      return 'Camera permission is required to answer this video call.';
    }
    if (message.contains('Agora App ID is missing')) {
      return 'Agora App ID is missing. Pass AGORA_APP_ID when running the receiver app.';
    }
    if (message.contains('Agora RTC token is required')) {
      return 'Agora token required. Configure CALL_API_BASE_URL for a token server or disable App Certificate in Agora Console for testing.';
    }
    if (message.contains('Token server returned')) {
      return 'Agora token server failed. Check CALL_API_BASE_URL and the /agora/fetchAgoraRtcToken endpoint.';
    }
    if (message.contains('ClientException') ||
        message.contains('Connection refused') ||
        message.contains('Failed host lookup')) {
      return 'Agora token server is unreachable. Start `npm run agora-token-server` locally or set CALL_API_BASE_URL to your token backend.';
    }
    return 'Unable to join the call. Check Agora configuration and try again.';
  }

  Future<void> _ensureAgoraPermissions(CallModel call) async {
    final microphone = await Permission.microphone.request();
    if (!microphone.isGranted) {
      throw StateError('Microphone permission is required to join calls.');
    }

    if (!call.isVideoCall) {
      return;
    }

    final camera = await Permission.camera.request();
    if (!camera.isGranted) {
      throw StateError('Camera permission is required to join video calls.');
    }
  }

  void _setIncomingCall(CallModel call) {
    _currentCall = call;
    _callState = CallUiState.incoming;
    _errorMessage = null;
    unawaited(_watchCurrentCall(call.callId));
    notifyListeners();
  }

  void _moveToActiveCall(CallModel call) {
    _currentCall = call;
    _callState = CallUiState.active;
    _errorMessage = null;
    notifyListeners();
  }

  void _restoreIncomingCall(CallModel call, {required String error}) {
    _currentCall = call;
    _callState = CallUiState.incoming;
    _errorMessage = error;
    notifyListeners();
  }

  Future<void> _watchCurrentCall(String callId) async {
    await _currentCallSubscription?.cancel();
    _currentCallSubscription = _firestoreService
        .watchCall(callId)
        .listen(
          (call) {
            if (call == null) {
              debugPrint('Receiver watchCall null: callId=$callId');
              unawaited(_markEndedThenReset());
              return;
            }

            _currentCall = call;
            debugPrint(
              'Receiver watchCall update: callId=${call.callId} '
              'status=${call.status.value}',
            );

            if (call.status == CallDocumentStatus.rejected ||
                call.status == CallDocumentStatus.ended) {
              unawaited(_markEndedThenReset());
              return;
            }

            if (call.status == CallDocumentStatus.connected ||
                call.status == CallDocumentStatus.accepted) {
              _callState = CallUiState.active;
            }

            notifyListeners();
          },
          onError: (_) {
            _errorMessage = 'Unable to track the active call.';
            notifyListeners();
          },
        );
  }

  Future<void> _markEndedThenReset() async {
    _callState = CallUiState.ended;
    notifyListeners();

    await _resetCallLocally(resetStateToIdle: false);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (_callState == CallUiState.ended) {
      _callState = CallUiState.idle;
      notifyListeners();
    }
  }

  Future<void> _resetCallLocally({required bool resetStateToIdle}) async {
    await _agoraService.leaveChannel();
    _currentCall = null;
    _localUserJoined = false;
    _remoteUid = null;
    _isMuted = false;
    _isVideoEnabled = true;
    _errorMessage = null;

    if (resetStateToIdle) {
      _callState = CallUiState.idle;
    }

    notifyListeners();
  }

  Future<void> _clearCurrentCallSubscription() async {
    await _currentCallSubscription?.cancel();
    _currentCallSubscription = null;
  }

  void _cancelIncomingCallListener() {
    _incomingCallSubscription?.cancel();
    _incomingCallSubscription = null;
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    _currentCallSubscription?.cancel();
    _notificationSubscription?.cancel();
    unawaited(_agoraService.dispose());
    super.dispose();
  }
}
