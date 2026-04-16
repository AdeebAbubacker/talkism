import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/call_model.dart';
import '../../providers/call_provider.dart';
import '../../widgets/primary_button.dart';

class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();
    final call = callProvider.currentCall;

    if (call == null) {
      return const Scaffold(
        body: Center(child: Text('No incoming call data found.')),
      );
    }

    final isVideo = call.callType == CallType.video;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        child: Icon(
                          isVideo ? Icons.videocam : Icons.call,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        call.callerName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Incoming ${call.callType.value} call',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (callProvider.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          callProvider.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Reject',
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              isLoading: callProvider.isBusy,
                              onPressed: () =>
                                  context.read<CallProvider>().rejectCall(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Accept',
                              isLoading: callProvider.isBusy,
                              onPressed: () =>
                                  context.read<CallProvider>().acceptCall(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
