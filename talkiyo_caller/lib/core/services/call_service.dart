import 'package:flutter/foundation.dart';

import '../../models/app_user.dart';
import '../../models/call_model.dart';
import '../constants/app_constants.dart';
import 'agora_service.dart';
import 'agora_token_service.dart';
import 'firestore_service.dart';

typedef CallJoinCallback = void Function();
typedef CallRemoteUserCallback = void Function(int uid);
typedef CallErrorCallback = void Function(String message);

class CallService {
  CallService({
    required FirestoreService firestoreService,
    required AgoraService agoraService,
    required AgoraTokenService agoraTokenService,
  }) : _firestoreService = firestoreService,
       _agoraService = agoraService,
       _agoraTokenService = agoraTokenService;

  final FirestoreService _firestoreService;
  final AgoraService _agoraService;
  final AgoraTokenService _agoraTokenService;

  Stream<CallModel?> watchCall(String callId) =>
      _firestoreService.watchCall(callId);

  Stream<CallModel?> watchIncomingCall(String receiverId) =>
      _firestoreService.watchIncomingCall(receiverId);

  Future<CallModel?> fetchCall(String callId) =>
      _firestoreService.fetchCall(callId);

  Future<CallModel> createCallInvite({
    required AppUser caller,
    required AppUser receiver,
    required String callerDeviceId,
  }) {
    return _firestoreService.createAudioCall(
      caller: caller,
      receiver: receiver,
      callerDeviceId: callerDeviceId,
    );
  }

  Future<CallModel?> acceptCall({
    required CallModel call,
    required String receiverDeviceId,
  }) => _firestoreService.acceptIncomingCall(
    callId: call.callId,
    deviceId: receiverDeviceId,
  );

  Future<void> rejectCall(CallModel call) {
    return _firestoreService.markCallTerminal(
      callId: call.callId,
      status: AppConstants.callStatusRejected,
      reason: AppConstants.callStatusRejected,
    );
  }

  Future<void> markBusy(CallModel call) {
    return _firestoreService.markCallTerminal(
      callId: call.callId,
      status: AppConstants.callStatusBusy,
      reason: AppConstants.callStatusBusy,
    );
  }

  Future<void> cancelOutgoingCall(CallModel call) {
    return _firestoreService.markCallTerminal(
      callId: call.callId,
      status: AppConstants.callStatusCancelled,
      reason: AppConstants.callStatusCancelled,
    );
  }

  Future<void> endAcceptedCall(CallModel call) {
    return _firestoreService.markCallTerminal(
      callId: call.callId,
      status: AppConstants.callStatusEnded,
      reason: AppConstants.callStatusEnded,
    );
  }

  Future<void> markTimedOutIfNeeded(String callId) {
    return _firestoreService.markCallTimedOutIfStillRinging(callId);
  }

  Future<void> joinAudioCall({
    required CallModel call,
    required String participantId,
    CallJoinCallback? onLocalJoinSuccess,
    CallRemoteUserCallback? onRemoteUserJoined,
    CallRemoteUserCallback? onRemoteUserLeft,
    CallErrorCallback? onError,
  }) async {
    final agoraUid = _agoraUidFrom(participantId);
    final token = await _resolveRtcToken(
      call: call,
      appUserId: _appUserIdForParticipant(call, participantId),
      participantId: participantId,
      agoraUid: agoraUid,
    );

    debugPrint(
      'Joining Agora channel ${call.channelName} for participant '
      '$participantId with uid $agoraUid.',
    );

    await _agoraService.joinAudioChannel(
      appId: AppConstants.agoraAppId,
      channelName: call.channelName,
      uid: agoraUid,
      token: token,
      onLocalJoinSuccess: onLocalJoinSuccess,
      onRemoteUserJoined: onRemoteUserJoined,
      onRemoteUserLeft: onRemoteUserLeft,
      onError: onError,
    );
  }

  Future<void> leaveChannel() => _agoraService.leaveChannel();

  Future<void> muteMicrophone(bool muted) =>
      _agoraService.muteMicrophone(muted);

  Future<void> setSpeakerEnabled(bool enabled) =>
      _agoraService.enableSpeakerphone(enabled);

  Future<String> _resolveRtcToken({
    required CallModel call,
    required String appUserId,
    required String participantId,
    required int agoraUid,
  }) async {
    final serverToken = await _agoraTokenService.fetchRtcToken(
      callId: call.callId,
      channelName: call.channelName,
      appUserId: appUserId,
      participantDeviceId: participantId,
      agoraUid: agoraUid,
    );
    if (serverToken.isNotEmpty) {
      debugPrint(
        'Resolved Agora token from token server for participant '
        '$participantId in call ${call.callId}.',
      );
      return serverToken;
    }

    final debugToken = AppConstants.agoraRtcToken.trim();
    if (kDebugMode && debugToken.isNotEmpty) {
      debugPrint(
        'Resolved Agora token from AGORA_RTC_TOKEN for participant '
        '$participantId in call ${call.callId}.',
      );
      return debugToken;
    }

    final legacyStoredToken = call.agoraToken.trim();
    if (legacyStoredToken.isNotEmpty) {
      debugPrint(
        'Using legacy call-document Agora token for participant '
        '$participantId in call ${call.callId}. This token must be valid '
        'for the participant UID $agoraUid.',
      );
      return legacyStoredToken;
    }

    throw StateError(
      'Agora RTC token is required. Set CALL_API_BASE_URL to a token server, '
      'provide AGORA_RTC_TOKEN for this exact channel/UID, use a legacy '
      'call-document token that matches this participant UID, or disable '
      'App Certificate in Agora Console for local testing.',
    );
  }

  String _appUserIdForParticipant(CallModel call, String participantId) {
    if (participantId == call.callerDeviceId) {
      return call.callerId;
    }
    if (participantId == call.acceptedByDeviceId) {
      return call.receiverId;
    }
    return call.callerId;
  }

  int _agoraUidFrom(String value) {
    if (value.trim().isEmpty) {
      return 0;
    }

    return value.hashCode.abs() % 1000000000;
  }
}
