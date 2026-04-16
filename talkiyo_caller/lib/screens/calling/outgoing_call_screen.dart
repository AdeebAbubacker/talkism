import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/call_controller.dart';
import '../call/active_call_screen.dart';

class OutgoingCallScreen extends StatefulWidget {
  const OutgoingCallScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const OutgoingCallScreen());
  }

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  bool _hasNavigatedToActive = false;
  bool _hasHandledCompletion = false;

  Future<void> _cancelCallFromBack() async {
    await context.read<CallController>().cancelCurrentCall();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _cancelCallFromBack();
        }
      },
      child: Consumer<CallController>(
        builder: (context, callController, _) {
          if (callController.callState == CallUiState.active &&
              !_hasNavigatedToActive) {
            _hasNavigatedToActive = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }

              Navigator.of(context).pushReplacement(ActiveCallScreen.route());
            });
          }

          if (callController.callState == CallUiState.ended &&
              !_hasHandledCompletion) {
            _hasHandledCompletion = true;
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 116,
                      width: 116,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFDCFCE7),
                      ),
                      child: const Icon(
                        Icons.ring_volume_rounded,
                        size: 46,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      callController.remoteDisplayName,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      callController.callState == CallUiState.connecting
                          ? 'Connecting to Agora...'
                          : 'Calling...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(
                      height: 34,
                      width: 34,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    if (callController.errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        callController.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    ],
                    const SizedBox(height: 40),
                    FilledButton.tonalIcon(
                      onPressed: callController.isBusy
                          ? null
                          : () async {
                              await context
                                  .read<CallController>()
                                  .cancelCurrentCall();
                            },
                      icon: const Icon(Icons.call_end),
                      label: const Text('Cancel Call'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        backgroundColor: const Color(0xFFFEE2E2),
                        foregroundColor: const Color(0xFFB91C1C),
                      ),
                    ),
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
