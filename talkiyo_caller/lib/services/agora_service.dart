import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/agora.config.dart' as config;

/// Callback types for Agora events
typedef OnUserJoined = void Function(int uid);
typedef OnUserOffline = void Function(int uid);
typedef OnError = void Function(String error);

/// Service for handling Agora RTC calling functionality
class AgoraService {
  RtcEngine? _engine;
  bool _isInitialized = false;
  int _localUid = 0;

  // Callbacks
  OnUserJoined? _onUserJoined;
  OnUserOffline? _onUserOffline;
  OnError? _onError;

  /// Initialize Agora RTC Engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(
        RtcEngineContext(
          appId: config.appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // Set event handlers
      _setupEventHandlers();

      _isInitialized = true;
    } catch (e) {
      _onError?.call('Failed to initialize Agora: $e');
      rethrow;
    }
  }

  /// Setup Agora event handlers
  void _setupEventHandlers() {
    final engine = _engine;
    if (engine == null) return;

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          _localUid = connection.localUid!;
          debugPrint('Joined channel: ${connection.channelId}');
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('Remote user joined: $remoteUid');
          _onUserJoined?.call(remoteUid);
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              debugPrint('Remote user offline: $remoteUid, reason: $reason');
              _onUserOffline?.call(remoteUid);
            },
        onError: (ErrorCodeType errorCode, String errorMsg) {
          debugPrint('Agora error: $errorCode - $errorMsg');
          _onError?.call('Error: $errorMsg');
        },
        onConnectionStateChanged:
            (
              RtcConnection connection,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              debugPrint('Connection state changed: $state, reason: $reason');
            },
      ),
    );
  }

  /// Set callbacks for Agora events
  void setCallbacks({
    OnUserJoined? onUserJoined,
    OnUserOffline? onUserOffline,
    OnError? onError,
  }) {
    _onUserJoined = onUserJoined;
    _onUserOffline = onUserOffline;
    _onError = onError;
  }

  /// Request microphone and optionally camera permissions.
  /// For audio-only calls, pass requireCamera: false.
  Future<bool> requestPermissions({bool requireCamera = true}) async {
    final permissions = [
      Permission.microphone,
      if (requireCamera) Permission.camera,
    ];

    final Map<Permission, PermissionStatus> statuses = await permissions
        .request();

    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    final camGranted =
        !requireCamera || (statuses[Permission.camera]?.isGranted ?? false);
    return micGranted && camGranted;
  }

  /// Join an Agora channel
  Future<void> joinChannel({
    required String channelName,
    required String token,
    required int uid,
    bool isAudioOnly = false,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      final engine = _engine;
      if (engine == null) {
        throw StateError('Agora engine is not initialized');
      }

      // Set channel profile
      await engine.setChannelProfile(
        ChannelProfileType.channelProfileCommunication,
      );

      // Set user role
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // Enable video if not audio-only
      if (!isAudioOnly) {
        await engine.enableVideo();
        await engine.startPreview();
      } else {
        await engine.disableVideo();
      }

      // Enable audio
      await engine.enableAudio();

      // Join channel
      await engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(),
      );
    } catch (e) {
      _onError?.call('Failed to join channel: $e');
      rethrow;
    }
  }

  /// Leave the current channel
  Future<void> leaveChannel() async {
    try {
      final engine = _engine;
      if (engine == null || !_isInitialized) return;
      await engine.leaveChannel();
      await engine.stopPreview();
    } catch (e) {
      _onError?.call('Failed to leave channel: $e');
      rethrow;
    }
  }

  /// Toggle microphone on/off
  Future<void> toggleMicrophone(bool enabled) async {
    try {
      final engine = _engine;
      if (engine == null || !_isInitialized) return;
      await engine.enableLocalAudio(enabled);
    } catch (e) {
      _onError?.call('Failed to toggle microphone: $e');
      rethrow;
    }
  }

  /// Toggle camera on/off
  Future<void> toggleCamera(bool enabled) async {
    try {
      final engine = _engine;
      if (engine == null || !_isInitialized) return;
      if (enabled) {
        await engine.enableLocalVideo(true);
        await engine.startPreview();
      } else {
        await engine.enableLocalVideo(false);
      }
    } catch (e) {
      _onError?.call('Failed to toggle camera: $e');
      rethrow;
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    try {
      final engine = _engine;
      if (engine == null || !_isInitialized) return;
      await engine.switchCamera();
    } catch (e) {
      _onError?.call('Failed to switch camera: $e');
      rethrow;
    }
  }

  /// Enable/disable speaker
  Future<void> enableSpeaker(bool enabled) async {
    try {
      final engine = _engine;
      if (engine == null || !_isInitialized) return;
      await engine.setEnableSpeakerphone(enabled);
    } catch (e) {
      _onError?.call('Failed to enable speaker: $e');
      rethrow;
    }
  }

  /// Dispose Agora engine
  Future<void> dispose() async {
    try {
      final engine = _engine;
      if (engine == null || !_isInitialized) return;
      _engine = null;
      _isInitialized = false;
      await engine.leaveChannel();
      await engine.release();
    } catch (e) {
      _onError?.call('Failed to dispose engine: $e');
    }
  }

  /// Get local video widget (for preview)
  Widget getLocalVideoWidget() {
    final engine = _engine;
    if (engine == null) return const SizedBox.shrink();

    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  /// Get remote video widget
  Widget getRemoteVideoWidget(int uid) {
    final engine = _engine;
    if (engine == null) return const SizedBox.shrink();

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: uid),
        connection: const RtcConnection(channelId: ''),
      ),
    );
  }

  /// Get local UID
  int getLocalUid() => _localUid;
}
