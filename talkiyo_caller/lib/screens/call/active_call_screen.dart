import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/call_controller.dart';

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const ActiveCallScreen());
  }

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  bool _handledEnd = false;

  Future<void> _leaveCallFromBack() async {
    await context.read<CallController>().leaveCall();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _leaveCallFromBack();
        }
      },
      child: Consumer<CallController>(
        builder: (context, callController, _) {
          if (callController.callState == CallUiState.ended && !_handledEnd) {
            _handledEnd = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) {
                return;
              }

              final message = callController.terminalMessage ?? 'Call ended.';
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
              await context.read<CallController>().reset();
              if (!mounted) {
                return;
              }

              navigator.pop();
            });
          }

          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton.filledTonal(
                        onPressed: () async {
                          await context.read<CallController>().leaveCall();
                        },
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 118,
                      width: 118,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F9D7A), Color(0xFF0A5E4A)],
                        ),
                      ),
                      child: const Icon(
                        Icons.headset_mic_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      callController.remoteDisplayName,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      callController.isRemoteUserJoined
                          ? 'Connected'
                          : 'Waiting for the other device to join audio',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      callController.formattedDuration,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (callController.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        callController.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CallActionButton(
                          label: callController.isMicMuted ? 'Unmute' : 'Mute',
                          icon: callController.isMicMuted
                              ? Icons.mic_off
                              : Icons.mic,
                          onPressed: callController.toggleMicrophone,
                        ),
                        _CallActionButton(
                          label: callController.isSpeakerEnabled
                              ? 'Speaker'
                              : 'Earpiece',
                          icon: callController.isSpeakerEnabled
                              ? Icons.volume_up
                              : Icons.hearing,
                          onPressed: callController.toggleSpeaker,
                        ),
                        _CallActionButton(
                          label: 'End',
                          icon: Icons.call_end,
                          backgroundColor: const Color(0xFFB91C1C),
                          foregroundColor: Colors.white,
                          onPressed: () async {
                            await context.read<CallController>().leaveCall();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 68,
          width: 68,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
            ),
            child: Icon(icon),
          ),
        ),
        const SizedBox(height: 10),
        Text(label),
      ],
    );
  }
}
