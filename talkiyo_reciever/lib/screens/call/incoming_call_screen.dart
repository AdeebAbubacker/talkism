import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/call_model.dart';
import '../../services/agora_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/ringtone_service.dart';
import 'active_call_screen.dart';

/// Incoming call screen for receiving calls
class IncomingCallScreen extends StatefulWidget {
  final CallModel call;
  final AgoraService agoraService;
  final FirestoreService firestoreService;

  const IncomingCallScreen({
    super.key,
    required this.call,
    required this.agoraService,
    required this.firestoreService,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  StreamSubscription<CallModel?>? _callStatusSub;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    unawaited(RingtoneService.startRinging());
    unawaited(NotificationService.cancelCallNotification(widget.call.callId));
    _listenForRemoteCancellation();
  }

  void _listenForRemoteCancellation() {
    _callStatusSub = widget.firestoreService
        .streamCallStatus(widget.call.callId)
        .listen(
          (updatedCall) {
            if (_isProcessing || !mounted) return;

            final shouldDismiss =
                updatedCall == null ||
                updatedCall.status == CallStatus.rejected ||
                updatedCall.status == CallStatus.ended ||
                updatedCall.status == CallStatus.missed;

            if (shouldDismiss) {
              _isProcessing = true;
              unawaited(RingtoneService.stopRinging());
              unawaited(
                NotificationService.cancelCallNotification(widget.call.callId),
              );
              Navigator.of(context).pop();
            }
          },
          onError: (error) {
            debugPrint('Error listening for incoming call status: $error');
          },
        );
  }

  /// Accept the incoming call
  Future<void> _acceptCall() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Request permissions
      final hasPermission = await widget.agoraService.requestPermissions(
        requireCamera: widget.call.callType == CallType.video,
      );
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permission denied. Please enable microphone and camera.',
              ),
            ),
          );
          setState(() => _isProcessing = false);
        }
        return;
      }

      await RingtoneService.stopRinging();

      // Update call status
      await widget.firestoreService.updateCallStatus(
        widget.call.callId,
        CallStatus.accepted,
      );
      await NotificationService.cancelCallNotification(widget.call.callId);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ActiveCallScreen(
              call: widget.call,
              agoraService: widget.agoraService,
              firestoreService: widget.firestoreService,
              isInitiator: false,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Reject the incoming call
  Future<void> _rejectCall() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await RingtoneService.stopRinging();
      await widget.firestoreService.updateCallStatus(
        widget.call.callId,
        CallStatus.rejected,
      );
      await NotificationService.cancelCallNotification(widget.call.callId);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _rejectCall();
      },
      child: Scaffold(
        backgroundColor: Colors.blue.shade900,
        body: SafeArea(
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
                        'Incoming Call',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white10,
                        child: Text(
                          widget.call.callerName.isNotEmpty
                              ? widget.call.callerName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.call.callerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.call.callerEmail,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                    ],
                  ),
                ),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Reject button
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.red,
                        child: IconButton(
                          icon: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: _isProcessing ? null : _rejectCall,
                        ),
                      ),
                      // Accept button
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.green,
                        child: _isProcessing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.call,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: _acceptCall,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _callStatusSub?.cancel();
    unawaited(RingtoneService.stopRinging());
    super.dispose();
  }
}
