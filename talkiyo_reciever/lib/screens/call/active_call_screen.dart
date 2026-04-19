import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../models/call_model.dart';
import '../../services/agora_service.dart';
import '../../services/firestore_service.dart';
import '../../config/agora.config.dart' as config;

/// Active call screen for ongoing calls
class ActiveCallScreen extends StatefulWidget {
  final CallModel call;
  final AgoraService agoraService;
  final FirestoreService firestoreService;
  final bool isInitiator;

  const ActiveCallScreen({
    Key? key,
    required this.call,
    required this.agoraService,
    required this.firestoreService,
    required this.isInitiator,
  }) : super(key: key);

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  late RtcEngine _engine;
  int? _remoteUserId;
  bool _isMicrophoneMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerEnabled = true;
  int _callDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _joinChannel();
    _startCallTimer();
  }

  /// Join Agora channel
  Future<void> _joinChannel() async {
    try {
      // Release the shared AgoraService engine so it doesn't compete for the
      // microphone while this screen manages its own dedicated engine.
      await widget.agoraService.dispose();

      _engine = createAgoraRtcEngine();
      await _engine.initialize(
        RtcEngineContext(
          appId: config.appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // Set event handlers
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('Joined channel successfully');
            _engine.setEnableSpeakerphone(_isSpeakerEnabled);
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('Remote user joined: $remoteUid');
            setState(() => _remoteUserId = remoteUid);
          },
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            debugPrint('Remote user offline: $remoteUid');
            setState(() => _remoteUserId = null);
            _endCall();
          },
          onError: (ErrorCodeType errorCode, String errorMsg) {
            debugPrint('Agora error: $errorCode - $errorMsg');
          },
        ),
      );

      // Set channel profile
      await _engine.setChannelProfile(
        ChannelProfileType.channelProfileCommunication,
      );

      // Set user role
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // Enable/disable video based on call type
      if (widget.call.callType == CallType.video) {
        await _engine.enableVideo();
        await _engine.startPreview();
      } else {
        await _engine.disableVideo();
      }

      // Enable audio
      await _engine.enableAudio();

      // Join channel
      final isAudioOnly = widget.call.callType == CallType.audio;
      await _engine.joinChannel(
        token: widget.call.token,
        channelId: widget.call.channelId,
        uid: 0,
        options: ChannelMediaOptions(
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: !isAudioOnly,
          publishCameraTrack: !isAudioOnly,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
    } catch (e) {
      debugPrint('Error joining channel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Start call timer
  void _startCallTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _callDurationSeconds++);
        _startCallTimer();
      }
    });
  }

  /// Format duration
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Toggle microphone
  Future<void> _toggleMicrophone() async {
    try {
      setState(() => _isMicrophoneMuted = !_isMicrophoneMuted);
      await _engine.enableLocalAudio(!_isMicrophoneMuted);
    } catch (e) {
      debugPrint('Error toggling microphone: $e');
    }
  }

  /// Toggle camera
  Future<void> _toggleCamera() async {
    try {
      if (widget.call.callType == CallType.video) {
        setState(() => _isCameraOff = !_isCameraOff);
        await _engine.enableLocalVideo(!_isCameraOff);
        if (!_isCameraOff) {
          await _engine.startPreview();
        }
      }
    } catch (e) {
      debugPrint('Error toggling camera: $e');
    }
  }

  /// Switch camera
  Future<void> _switchCamera() async {
    try {
      if (widget.call.callType == CallType.video && !_isCameraOff) {
        await _engine.switchCamera();
      }
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }

  /// Toggle speaker
  Future<void> _toggleSpeaker() async {
    try {
      setState(() => _isSpeakerEnabled = !_isSpeakerEnabled);
      await _engine.setEnableSpeakerphone(_isSpeakerEnabled);
    } catch (e) {
      debugPrint('Error toggling speaker: $e');
    }
  }

  /// End call
  Future<void> _endCall() async {
    try {
      // Update call status in Firestore
      await widget.firestoreService.updateCallStatus(
        widget.call.callId,
        CallStatus.ended,
      );

      // Leave channel
      await _engine.leaveChannel();
      await _engine.release();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _endCall();
        },
        child: SafeArea(
          child: widget.call.callType == CallType.video
              ? _buildVideoCallUI()
              : _buildAudioCallUI(),
        ),
      ),
    );
  }

  /// Build video call UI
  Widget _buildVideoCallUI() {
    return Stack(
      children: [
        // Remote video (full screen)
        if (_remoteUserId != null)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: _remoteUserId!),
              connection: RtcConnection(channelId: widget.call.channelId),
            ),
          )
        else
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_off,
                    size: 64,
                    color: Colors.white30,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Waiting for user to join...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

        // Local video (PiP)
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _engine,
                canvas: const VideoCanvas(uid: 0),
              ),
            ),
          ),
        ),

        // Header with caller info
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isInitiator
                          ? widget.call.receiverName
                          : widget.call.callerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatDuration(_callDurationSeconds),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Control buttons
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Microphone toggle
              _buildControlButton(
                icon: _isMicrophoneMuted ? Icons.mic_off : Icons.mic,
                color: _isMicrophoneMuted ? Colors.red : Colors.white,
                onPressed: _toggleMicrophone,
              ),
              const SizedBox(width: 16),

              // Camera toggle
              _buildControlButton(
                icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                color: _isCameraOff ? Colors.red : Colors.white,
                onPressed: _toggleCamera,
              ),
              const SizedBox(width: 16),

              // Switch camera
              _buildControlButton(
                icon: Icons.cameraswitch,
                color: Colors.white,
                onPressed: _switchCamera,
              ),
              const SizedBox(width: 16),

              // End call
              _buildControlButton(
                icon: Icons.call_end,
                color: Colors.red,
                size: 36,
                onPressed: _endCall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build audio call UI
  Widget _buildAudioCallUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Caller info
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue.shade900,
                  child: Text(
                    widget.isInitiator
                        ? widget.call.receiverName.isNotEmpty
                            ? widget.call.receiverName[0].toUpperCase()
                            : 'U'
                        : widget.call.callerName.isNotEmpty
                            ? widget.call.callerName[0].toUpperCase()
                            : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.isInitiator
                      ? widget.call.receiverName
                      : widget.call.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatDuration(_callDurationSeconds),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

          // Control buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Microphone toggle
                _buildControlButton(
                  icon: _isMicrophoneMuted ? Icons.mic_off : Icons.mic,
                  color: _isMicrophoneMuted ? Colors.red : Colors.white,
                  onPressed: _toggleMicrophone,
                ),
                const SizedBox(width: 16),

                // Speaker toggle
                _buildControlButton(
                  icon: _isSpeakerEnabled
                      ? Icons.speaker
                      : Icons.speaker_notes_off,
                  color: _isSpeakerEnabled ? Colors.white : Colors.red,
                  onPressed: _toggleSpeaker,
                ),
                const SizedBox(width: 16),

                // End call
                _buildControlButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  size: 36,
                  onPressed: _endCall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build control button widget
  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 28,
  }) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      child: IconButton(
        icon: Icon(icon, color: color, size: size),
        onPressed: onPressed,
      ),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel().then((_) => _engine.release());
    super.dispose();
  }
}
