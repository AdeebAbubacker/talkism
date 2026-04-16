import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/call_controller.dart';
import '../call/active_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const IncomingCallScreen());
  }

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _hasNavigatedToActive = false;
  bool _hasHandledCompletion = false;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
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
                        color: Color(0xFFDBEAFE),
                      ),
                      child: const Icon(
                        Icons.call_rounded,
                        size: 46,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      callController.remoteDisplayName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Incoming Talkiyo voice call',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                    if (callController.currentCall?.callerPhoneNumber
                            .trim()
                            .isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 8),
                      Text(
                        callController.currentCall!.callerPhoneNumber,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    if (callController.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        callController.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    ],
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.tonal(
                          onPressed: callController.isBusy
                              ? null
                              : () async {
                                  await context
                                      .read<CallController>()
                                      .rejectIncomingCall();
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFEE2E2),
                            foregroundColor: const Color(0xFFB91C1C),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                          ),
                          child: const Icon(Icons.call_end),
                        ),
                        const SizedBox(width: 20),
                        FilledButton(
                          onPressed: callController.isBusy
                              ? null
                              : () async {
                                  await context
                                      .read<CallController>()
                                      .acceptIncomingCall();
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF15803D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                          ),
                          child: const Icon(Icons.call),
                        ),
                      ],
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
