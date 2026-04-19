import 'package:flutter/material.dart';
import '../../models/call_model.dart';
import '../../services/agora_service.dart';
import '../../services/firestore_service.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../config/agora.config.dart' as config;
import 'incoming_call_screen.dart';
import 'active_call_screen.dart';

/// Outgoing call screen for ringing state
class OutgoingCallScreen extends StatefulWidget {
  final CallModel call;
  final AgoraService agoraService;
  final FirestoreService firestoreService;

  const OutgoingCallScreen({
    Key? key,
    required this.call,
    required this.agoraService,
    required this.firestoreService,
  }) : super(key: key);

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  late Stream<CallModel?> _callStatusStream;
  bool _isCallRinging = true;

  @override
  void initState() {
    super.initState();
    _callStatusStream =
        widget.firestoreService.streamCallStatus(widget.call.callId);
  }

  /// Cancel the outgoing call
  Future<void> _cancelCall() async {
    try {
      await widget.firestoreService.updateCallStatus(
        widget.call.callId,
        CallStatus.rejected,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelCall();
      },
      child: Scaffold(
        backgroundColor: Colors.blue.shade900,
        body: StreamBuilder<CallModel?>(
          stream: _callStatusStream,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final updatedCall = snapshot.data!;

              // If call was accepted, navigate to active call screen
              if (updatedCall.status == CallStatus.accepted) {
                Future.microtask(() {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ActiveCallScreen(
                        call: updatedCall,
                        agoraService: widget.agoraService,
                        firestoreService: widget.firestoreService,
                        isInitiator: true,
                      ),
                    ),
                  );
                });
              }

              // If call was rejected, show message and pop
              if (updatedCall.status == CallStatus.rejected) {
                Future.microtask(() {
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Call rejected'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                });
              }
            }

            return SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          const Text(
                            'Calling...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.call.receiverName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.call.receiverEmail,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Call type indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.call.callType == CallType.video
                                ? Icons.videocam
                                : Icons.call,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.call.callType == CallType.video
                                ? 'Video Call'
                                : 'Audio Call',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Cancel button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.red,
                        child: IconButton(
                          icon: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: _cancelCall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
