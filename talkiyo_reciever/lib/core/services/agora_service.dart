import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../constants/app_constants.dart';

class AgoraServiceCallbacks {
  const AgoraServiceCallbacks({
    required this.onLocalJoinSuccess,
    required this.onRemoteUserJoined,
    required this.onRemoteUserLeft,
    required this.onError,
  });

  final void Function() onLocalJoinSuccess;
  final void Function(int uid) onRemoteUserJoined;
  final void Function(int uid) onRemoteUserLeft;
  final void Function(String message) onError;
}

class AgoraService {
  RtcEngine? _engine;
  AgoraServiceCallbacks? _callbacks;
  bool _isInitialized = false;
  bool _videoEnabled = false;
  String? _currentChannelName;

  RtcEngine? get engine => _engine;

  Future<void> initialize({required AgoraServiceCallbacks callbacks}) async {
    _callbacks = callbacks;

    if (_isInitialized && _engine != null) {
      return;
    }

    if (!AppConstants.isAgoraConfigured) {
      throw Exception(
        'Agora App ID is missing. Update AppConstants.agoraAppId before testing calls.',
      );
    }

    final engine = createAgoraRtcEngine();
    await engine.initialize(
      const RtcEngineContext(
        appId: AppConstants.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _callbacks?.onLocalJoinSuccess();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _callbacks?.onRemoteUserJoined(remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          _callbacks?.onRemoteUserLeft(remoteUid);
        },
        onError: (errorCode, message) {
          final fallbackMessage = message.isNotEmpty
              ? message
              : 'Agora error: ${errorCode.value()}';
          _callbacks?.onError(fallbackMessage);
        },
      ),
    );

    await engine.enableAudio();

    _engine = engine;
    _isInitialized = true;
  }

  Future<void> joinChannel({
    required String channelName,
    String? token,
    required int uid,
    required bool enableVideo,
  }) async {
    final engine = _engine;
    if (!_isInitialized || engine == null) {
      throw Exception('Agora engine is not initialized.');
    }

    if (_currentChannelName == channelName) {
      return;
    }

    if (_currentChannelName != null && _currentChannelName != channelName) {
      await engine.leaveChannel();
      _currentChannelName = null;
    }

    _videoEnabled = enableVideo;

    if (enableVideo) {
      await engine.enableVideo();
      await engine.startPreview();
    } else {
      await engine.stopPreview();
      await engine.disableVideo();
    }

    await engine.joinChannel(
      token: token ?? '',
      channelId: channelName,
      uid: uid,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: enableVideo,
        autoSubscribeAudio: true,
        autoSubscribeVideo: enableVideo,
      ),
    );
    _currentChannelName = channelName;
  }

  Future<void> muteLocalAudio(bool muted) async {
    final engine = _engine;
    if (engine == null) {
      return;
    }
    await engine.muteLocalAudioStream(muted);
  }

  Future<void> setLocalVideoEnabled(bool enabled) async {
    final engine = _engine;
    if (engine == null) {
      return;
    }

    _videoEnabled = enabled;

    if (enabled) {
      await engine.enableVideo();
      await engine.muteLocalVideoStream(false);
      await engine.startPreview();
    } else {
      await engine.muteLocalVideoStream(true);
      await engine.stopPreview();
    }
  }

  Future<void> switchCamera() async {
    final engine = _engine;
    if (engine == null || !_videoEnabled) {
      return;
    }
    await engine.switchCamera();
  }

  Future<void> leaveChannel() async {
    final engine = _engine;
    if (engine == null) {
      return;
    }

    if (_videoEnabled) {
      await engine.stopPreview();
    }

    await engine.leaveChannel();
    _currentChannelName = null;
  }

  Future<void> dispose() async {
    final engine = _engine;
    if (engine == null) {
      return;
    }

    await engine.release();
    _engine = null;
    _callbacks = null;
    _isInitialized = false;
    _videoEnabled = false;
    _currentChannelName = null;
  }
}
