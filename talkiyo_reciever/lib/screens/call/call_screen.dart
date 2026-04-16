import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/call_provider.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();
    final call = callProvider.currentCall;

    if (call == null) {
      return const Scaffold(
        body: Center(child: Text('Call data is unavailable.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: call.isVideoCall
                  ? _VideoLayout(callProvider: callProvider)
                  : _AudioLayout(callProvider: callProvider),
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.callerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        call.isVideoCall ? 'Video call' : 'Audio call',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  if (callProvider.errorMessage != null)
                    Flexible(
                      child: Text(
                        callProvider.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.right,
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ControlButton(
                    icon: callProvider.isMuted ? Icons.mic_off : Icons.mic,
                    label: callProvider.isMuted ? 'Unmute' : 'Mute',
                    onTap: () => context.read<CallProvider>().toggleMute(),
                  ),
                  if (call.isVideoCall)
                    _ControlButton(
                      icon: callProvider.isVideoEnabled
                          ? Icons.videocam
                          : Icons.videocam_off,
                      label: callProvider.isVideoEnabled
                          ? 'Video Off'
                          : 'Video On',
                      onTap: () => context.read<CallProvider>().toggleVideo(),
                    ),
                  if (call.isVideoCall)
                    _ControlButton(
                      icon: Icons.cameraswitch,
                      label: 'Switch',
                      onTap: () => context.read<CallProvider>().switchCamera(),
                    ),
                  _ControlButton(
                    icon: Icons.call_end,
                    label: 'Leave',
                    backgroundColor: Colors.redAccent,
                    onTap: () => context.read<CallProvider>().endCall(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioLayout extends StatelessWidget {
  const _AudioLayout({required this.callProvider});

  final CallProvider callProvider;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.white10,
            child: const Icon(Icons.person, size: 64, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            callProvider.remoteUid != null
                ? 'Connected to remote user ${callProvider.remoteUid}'
                : 'Waiting for caller to connect...',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _VideoLayout extends StatelessWidget {
  const _VideoLayout({required this.callProvider});

  final CallProvider callProvider;

  @override
  Widget build(BuildContext context) {
    final engine = callProvider.agoraEngine;
    final call = callProvider.currentCall;

    if (engine == null || call == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: callProvider.remoteUid == null
              ? const Center(
                  child: Text(
                    'Waiting for remote video...',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                )
              : AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: engine,
                    canvas: VideoCanvas(uid: callProvider.remoteUid),
                    connection: RtcConnection(channelId: call.channelName),
                  ),
                ),
        ),
        Positioned(
          right: 16,
          top: 100,
          width: 120,
          height: 180,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white10,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: callProvider.localUserJoined
                  ? AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: engine,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor = Colors.white12,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
