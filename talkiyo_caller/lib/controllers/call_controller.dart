import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants/app_constants.dart';
import '../core/services/call_service.dart';
import '../core/services/installation_service.dart';
import '../core/services/notification_service.dart';
import '../models/app_user.dart';
import '../models/call_model.dart';
import '../models/call_notification_payload.dart';

enum CallUiState { idle, outgoing, incoming, connecting, active, ended }

class CallController extends ChangeNotifier {
  CallController({
    required CallService callService,
    required NotificationService notificationService,
    required InstallationService installationService,
  }) : _callService = callService,
       _notificationService = notificationService,
       _installationService = installationService;

  final CallService _callService;
  final NotificationService _notificationService;
  final InstallationService _installationService;

  StreamSubscription<CallModel?>? _callSubscription;
  StreamSubscription<CallModel?>? _incomingCallSubscription;
  StreamSubscription<CallNotificationPayload>? _notificationSubscription;
  Timer? _callTimer;
  Timer? _ringTimeoutTimer;

  final Set<String> _seenIncomingCallIds = <String>{};
  final List<CallNotificationPayload> _pendingNotificationPayloads =
      <CallNotificationPayload>[];

  AppUser? _currentUser;
  CallModel? _currentCall;
  String? _installationId;
  CallUiState _callState = CallUiState.idle;
  Duration _callDuration = Duration.zero;
  bool _isBusy = false;
  bool _isMicMuted = false;
  bool _isSpeakerEnabled = true;
  bool _isRemoteUserJoined = false;
  bool _isJoiningAgora = false;
  bool _isInitialized = false;
  String? _errorMessage;
  String? _terminalMessage;

  AppUser? get currentUser => _currentUser;
  CallModel? get currentCall => _currentCall;
  CallUiState get callState => _callState;
  Duration get callDuration => _callDuration;
  bool get isBusy => _isBusy;
  bool get isMicMuted => _isMicMuted;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  bool get isRemoteUserJoined => _isRemoteUserJoined;
  bool get hasIncomingCall =>
      _callState == CallUiState.incoming && _currentCall != null;
  bool get isIncomingForCurrentDevice =>
      _currentUser?.uid.isNotEmpty == true &&
      _currentCall?.receiverId == _currentUser?.uid;
  String? get errorMessage => _errorMessage;
  String? get terminalMessage => _terminalMessage;
  String get remoteDisplayName {
    final call = _currentCall;
    final currentUserId = _currentUser?.uid;
    if (call == null || currentUserId == null) {
      return 'Talkiyo User';
    }

    return currentUserId == call.callerId ? call.receiverName : call.callerName;
  }

  String get formattedDuration {
    final minutes = _callDuration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _callDuration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void bindCurrentUser(AppUser? user) {
    final previousUserId = _currentUser?.uid;
    final nextUserId = user?.uid;
    _currentUser = user;

    if (previousUserId == nextUserId) {
      return;
    }

    unawaited(_configureForCurrentUser());
  }

  Future<bool> startOutgoingCall({
    required AppUser caller,
    required AppUser receiver,
  }) async {
    if (!receiver.isOnline) {
      _errorMessage = '${receiver.displayName} is offline right now.';
      notifyListeners();
      return false;
    }

    await _ensureInitialized();
    await _resetCallState();

    final installationId = _installationId;
    if (installationId == null || installationId.isEmpty) {
      _errorMessage = 'Unable to resolve this device ID for calling.';
      notifyListeners();
      return false;
    }

    _currentUser = caller;
    _errorMessage = null;
    _terminalMessage = null;
    _callState = CallUiState.outgoing;
    _setBusy(true);
    notifyListeners();

    try {
      final call = await _callService.createCallInvite(
        caller: caller,
        receiver: receiver,
        callerDeviceId: installationId,
      );
      _currentCall = call;
      _listenToCall(call.callId);
      _scheduleRingTimeoutCheck(call);
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Unable to create the call invitation.';
      _callState = CallUiState.ended;
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> acceptIncomingCall() async {
    final call = _currentCall;
    final installationId = _installationId;
    if (call == null || installationId == null) {
      return;
    }

    _setBusy(true);
    _errorMessage = null;
    notifyListeners();

    try {
      await _callService.acceptCall(
        call: call,
        receiverDeviceId: installationId,
      );
    } catch (error) {
      _errorMessage = 'Unable to accept the incoming call.';
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> rejectIncomingCall() async {
    final call = _currentCall;
    if (call == null) {
      return;
    }

    await _callService.rejectCall(call);
    await _transitionToTerminal('Call declined.');
  }

  Future<void> cancelCurrentCall() async {
    final call = _currentCall;
    if (call == null) {
      return;
    }

    await _callService.cancelOutgoingCall(call);
    await _transitionToTerminal('Call cancelled.');
  }

  Future<void> leaveCall() async {
    final call = _currentCall;
    if (call == null) {
      return;
    }

    await _callService.endAcceptedCall(call);
    await _transitionToTerminal('Call ended.');
  }

  Future<void> toggleMicrophone() async {
    _isMicMuted = !_isMicMuted;
    notifyListeners();
    await _callService.muteMicrophone(_isMicMuted);
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerEnabled = !_isSpeakerEnabled;
    notifyListeners();
    await _callService.setSpeakerEnabled(_isSpeakerEnabled);
  }

  Future<void> reset() async {
    await _resetCallState();
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _terminalMessage = null;
    notifyListeners();
  }

  Future<void> _configureForCurrentUser() async {
    await _ensureInitialized();

    await _incomingCallSubscription?.cancel();
    if (_currentUser == null) {
      await _resetCallState();
      notifyListeners();
      return;
    }

    _incomingCallSubscription = _callService
        .watchIncomingCall(_currentUser!.uid)
        .listen(
          (call) {
            if (call == null) {
              return;
            }

            unawaited(_ingestIncomingCall(call));
          },
          onError: (Object error) {
            _errorMessage = 'Unable to listen for incoming calls.';
            notifyListeners();
          },
        );

    if (_pendingNotificationPayloads.isNotEmpty) {
      final pending = List<CallNotificationPayload>.from(
        _pendingNotificationPayloads,
      );
      _pendingNotificationPayloads.clear();
      for (final payload in pending) {
        unawaited(_handleNotificationPayload(payload));
      }
    }
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) {
      return;
    }

    await _notificationService.initialize();
    _installationId = await _installationService.getInstallationId();
    _notificationSubscription = _notificationService.onCallEvent.listen((
      payload,
    ) {
      if (_currentUser == null) {
        _pendingNotificationPayloads.add(payload);
        return;
      }

      unawaited(_handleNotificationPayload(payload));
    });

    final initialPayload = await _notificationService
        .getInitialNotificationPayload();
    if (initialPayload != null) {
      _pendingNotificationPayloads.add(initialPayload);
    }

    _isInitialized = true;
  }

  Future<void> _handleNotificationPayload(
    CallNotificationPayload payload,
  ) async {
    if (_currentUser == null) {
      _pendingNotificationPayloads.add(payload);
      return;
    }

    if (payload.receiverId != _currentUser!.uid) {
      return;
    }

    final call = await _callService.fetchCall(payload.callId);
    if (call == null) {
      return;
    }

    await _ingestIncomingCall(call);
  }

  Future<void> _ingestIncomingCall(CallModel call) async {
    if (_currentUser == null || call.receiverId != _currentUser!.uid) {
      return;
    }

    if (call.ringTimeoutAt != null &&
        call.ringTimeoutAt!.isBefore(DateTime.now())) {
      await _callService.markTimedOutIfNeeded(call.callId);
      return;
    }

    if (call.status != AppConstants.callStatusRinging) {
      await _handleCallUpdate(call);
      return;
    }

    final isDifferentActiveCall =
        _currentCall != null &&
        _currentCall!.callId != call.callId &&
        (_callState == CallUiState.incoming ||
            _callState == CallUiState.connecting ||
            _callState == CallUiState.active ||
            _callState == CallUiState.outgoing);

    if (isDifferentActiveCall) {
      await _callService.markBusy(call);
      return;
    }

    if (_seenIncomingCallIds.contains(call.callId) &&
        _currentCall?.callId == call.callId) {
      return;
    }

    _seenIncomingCallIds.add(call.callId);
    _currentCall = call;
    _callState = CallUiState.incoming;
    _errorMessage = null;
    _terminalMessage = null;
    _listenToCall(call.callId);
    _scheduleRingTimeoutCheck(call);
    notifyListeners();
  }

  void _listenToCall(String callId) {
    _callSubscription?.cancel();
    _callSubscription = _callService
        .watchCall(callId)
        .listen(
          (call) {
            if (call == null) {
              return;
            }

            _currentCall = call;
            unawaited(_handleCallUpdate(call));
          },
          onError: (Object error) {
            _errorMessage = 'Unable to listen to call updates.';
            notifyListeners();
          },
        );
  }

  Future<void> _handleCallUpdate(CallModel call) async {
    _currentCall = call;
    debugPrint(
      'CallController update: callId=${call.callId} status=${call.status} '
      'state=$_callState acceptedByDeviceId=${call.acceptedByDeviceId} '
      'localInstallation=$_installationId',
    );

    switch (call.status) {
      case AppConstants.callStatusRinging:
        _scheduleRingTimeoutCheck(call);
        if (_currentUser?.uid == call.receiverId) {
          _callState = CallUiState.incoming;
        } else {
          _callState = CallUiState.outgoing;
        }
        notifyListeners();
        return;
      case AppConstants.callStatusAccepted:
        await _notificationService.cancelIncomingCallNotification(call.callId);
        final acceptedElsewhere =
            _currentUser?.uid == call.receiverId &&
            call.acceptedByDeviceId != null &&
            call.acceptedByDeviceId != _installationId;
        if (acceptedElsewhere) {
          await _transitionToTerminal('Answered on another device.');
          return;
        }

        if (_callState != CallUiState.active &&
            _callState != CallUiState.connecting &&
            !_isJoiningAgora) {
          _callState = CallUiState.connecting;
          notifyListeners();
          await _joinAcceptedCall(call);
        }
        return;
      case AppConstants.callStatusRejected:
        await _transitionToTerminal('Call declined.');
        return;
      case AppConstants.callStatusCancelled:
        await _transitionToTerminal('Caller cancelled before answer.');
        return;
      case AppConstants.callStatusBusy:
        await _transitionToTerminal('User is busy on another device.');
        return;
      case AppConstants.callStatusTimeout:
        await _transitionToTerminal(
          _currentUser?.uid == call.receiverId ? 'Missed call.' : 'No answer.',
        );
        return;
      case AppConstants.callStatusMissed:
        await _transitionToTerminal('Missed call.');
        return;
      case AppConstants.callStatusEnded:
        await _transitionToTerminal('Call ended.');
        return;
    }
  }

  Future<void> _joinAcceptedCall(CallModel call) async {
    if (_isJoiningAgora) {
      return;
    }

    if (AppConstants.agoraAppId.trim().isEmpty) {
      _errorMessage =
          'Agora App ID is missing. Pass AGORA_APP_ID with --dart-define.';
      await _transitionToTerminal('Agora is not configured.');
      return;
    }

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      _errorMessage = 'Microphone permission is required for audio calling.';
      await _transitionToTerminal('Microphone permission denied.');
      return;
    }

    final participantId = _installationId ?? _currentUser?.uid;
    if (participantId == null || participantId.isEmpty) {
      _errorMessage = 'Unable to resolve the local participant identity.';
      await _transitionToTerminal('Failed to connect the call.');
      return;
    }

    _isJoiningAgora = true;
    notifyListeners();

    try {
      debugPrint(
        'CallController joining Agora: callId=${call.callId} '
        'channel=${call.channelName} state=$_callState',
      );
      await _callService.joinAudioCall(
        call: call,
        participantId: participantId,
        onLocalJoinSuccess: () {
          debugPrint(
            'CallController local Agora join success: '
            'callId=${call.callId} channel=${call.channelName}',
          );
          _callState = CallUiState.active;
          _startCallTimer();
          notifyListeners();
        },
        onRemoteUserJoined: (uid) {
          debugPrint(
            'CallController remote Agora user joined: '
            'callId=${call.callId} remoteUid=$uid',
          );
          _isRemoteUserJoined = true;
          notifyListeners();
        },
        onRemoteUserLeft: (uid) {
          debugPrint(
            'CallController remote Agora user left: '
            'callId=${call.callId} remoteUid=$uid',
          );
          _isRemoteUserJoined = false;
          notifyListeners();
          unawaited(_transitionToTerminal('$remoteDisplayName left the call.'));
        },
        onError: (message) {
          _errorMessage = message;
          notifyListeners();
        },
      );
    } catch (error) {
      _errorMessage = _mapAgoraJoinError(error);
      try {
        await _callService.endAcceptedCall(call);
      } catch (_) {
        // Best-effort cleanup so the receiver does not remain stuck in-call.
      }
      await _transitionToTerminal('Failed to connect the call.');
    } finally {
      _isJoiningAgora = false;
      notifyListeners();
    }
  }

  void _scheduleRingTimeoutCheck(CallModel call) {
    _ringTimeoutTimer?.cancel();
    final timeoutAt = call.ringTimeoutAt;
    if (timeoutAt == null) {
      return;
    }

    final waitDuration = timeoutAt.difference(DateTime.now());
    if (waitDuration.isNegative) {
      unawaited(_callService.markTimedOutIfNeeded(call.callId));
      return;
    }

    _ringTimeoutTimer = Timer(waitDuration, () {
      unawaited(_callService.markTimedOutIfNeeded(call.callId));
    });
  }

  String _mapAgoraJoinError(Object error) {
    final message = error.toString();
    if (message.contains('Agora RTC token is required')) {
      return 'Agora token required. Configure CALL_API_BASE_URL for a token server or disable App Certificate in Agora Console for testing.';
    }
    return 'Unable to join the Agora audio channel.';
  }

  Future<void> _transitionToTerminal(String message) async {
    debugPrint(
      'CallController transitionToTerminal: callId=${_currentCall?.callId} '
      'state=$_callState message="$message"',
    );
    _callTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    _callTimer = null;
    _ringTimeoutTimer = null;
    await _callService.leaveChannel();
    final activeCallId = _currentCall?.callId;
    if (activeCallId != null) {
      await _notificationService.cancelIncomingCallNotification(activeCallId);
    }

    _callState = CallUiState.ended;
    _terminalMessage = message;
    notifyListeners();
  }

  Future<void> _resetCallState() async {
    _callTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    _callTimer = null;
    _ringTimeoutTimer = null;
    _callDuration = Duration.zero;
    _isMicMuted = false;
    _isSpeakerEnabled = true;
    _isRemoteUserJoined = false;
    _isJoiningAgora = false;
    _isBusy = false;
    _errorMessage = null;
    _terminalMessage = null;
    _callState = CallUiState.idle;
    await _callSubscription?.cancel();
    _callSubscription = null;
    await _callService.leaveChannel();
    final callId = _currentCall?.callId;
    _currentCall = null;
    if (callId != null) {
      await _notificationService.cancelIncomingCallNotification(callId);
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callDuration = Duration.zero;
    notifyListeners();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    _notificationSubscription?.cancel();
    _callTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    _callService.leaveChannel();
    super.dispose();
  }
}
