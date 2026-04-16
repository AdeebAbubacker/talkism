import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

typedef AgoraJoinCallback = void Function();
typedef AgoraRemoteUserCallback = void Function(int uid);
typedef AgoraErrorCallback = void Function(String message);

class AgoraService {
  RtcEngine? _engine;
  String? _currentChannelName;

  bool get isInitialized => _engine != null;

  Future<void> joinAudioChannel({
    required String appId,
    required String channelName,
    required int uid,
    String? token,
    AgoraJoinCallback? onLocalJoinSuccess,
    AgoraRemoteUserCallback? onRemoteUserJoined,
    AgoraRemoteUserCallback? onRemoteUserLeft,
    AgoraErrorCallback? onError,
  }) async {
    if (_engine == null) {
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      await engine.enableAudio();
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            onLocalJoinSuccess?.call();
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            onRemoteUserJoined?.call(remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            onRemoteUserLeft?.call(remoteUid);
          },
          onError: (error, message) {
            onError?.call('Agora error ${error.value()}: $message');
          },
        ),
      );
      _engine = engine;
    }

    if (_currentChannelName == channelName) {
      return;
    }

    if (_currentChannelName != null && _currentChannelName != channelName) {
      await _engine!.leaveChannel();
      _currentChannelName = null;
    }

    try {
      await _engine!.enableLocalAudio(true);
      await _engine!.muteLocalAudioStream(false);
      await _engine!.joinChannel(
        token: token?.trim() ?? '',
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ),
      );
      _currentChannelName = channelName;
      try {
        await _engine!.setEnableSpeakerphone(true);
      } catch (error, stackTrace) {
        debugPrint(
          'Unable to enable speakerphone, continuing with the joined call: '
          '$error\n$stackTrace',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Agora join failed: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<void> muteMicrophone(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> enableSpeakerphone(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
  }

  Future<void> leaveChannel() async {
    if (_engine == null) {
      return;
    }

    await _engine!.leaveChannel();
    await _engine!.release();
    _engine = null;
    _currentChannelName = null;
  }
}
