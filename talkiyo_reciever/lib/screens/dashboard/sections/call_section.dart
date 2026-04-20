import 'package:flutter/material.dart';

import '../../../models/call_model.dart';
import '../../../services/firestore_service.dart';

class CallSection extends StatelessWidget {
  final String currentUserId;
  final FirestoreService firestoreService;
  final void Function(CallModel call, bool isVideoCall)? onStartCall;

  const CallSection({
    super.key,
    required this.currentUserId,
    required this.firestoreService,
    this.onStartCall,
  });

  @override
  Widget build(BuildContext context) {
    if (currentUserId.isEmpty) {
      return const _CallEmptyState(
        icon: Icons.lock_outline,
        title: 'Login required',
        message: 'Your previous calls will appear after login.',
      );
    }

    return StreamBuilder<List<CallModel>>(
      stream: firestoreService.streamRecentCalls(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _CallEmptyState(
            icon: Icons.error_outline,
            title: 'Could not load calls',
            message: snapshot.error.toString(),
          );
        }

        final calls = snapshot.data ?? [];

        if (calls.isEmpty) {
          return const _CallEmptyState(
            icon: Icons.call_outlined,
            title: 'No calls yet',
            message: 'Users you have connected with will show here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
          children: [
            const Text(
              'Previously Connected',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Recent users and call time',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            _CallSummary(calls: calls, currentUserId: currentUserId),
            const SizedBox(height: 18),
            ...calls.map(
              (call) => _CallHistoryTile(
                call: call,
                currentUserId: currentUserId,
                onStartCall: onStartCall,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CallSummary extends StatelessWidget {
  final List<CallModel> calls;
  final String currentUserId;

  const _CallSummary({required this.calls, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final totalSeconds = calls.fold<int>(
      0,
      (sum, call) => sum + (call.getDurationInSeconds() ?? 0),
    );
    final connectedCalls = calls.where((call) {
      return call.status == CallStatus.ended || call.acceptedAt != null;
    }).length;
    final connectedUsers = calls
        .map((call) => _otherUserId(call, currentUserId))
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;

    return Row(
      children: [
        Expanded(
          child: _SummaryBox(
            icon: Icons.people_outline,
            label: 'Users',
            value: connectedUsers.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryBox(
            icon: Icons.call_outlined,
            label: 'Calls',
            value: connectedCalls.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryBox(
            icon: Icons.timer_outlined,
            label: 'Time',
            value: _formatCompactDuration(totalSeconds),
          ),
        ),
      ],
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF7E3DFF), size: 24),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CallHistoryTile extends StatelessWidget {
  final CallModel call;
  final String currentUserId;
  final void Function(CallModel call, bool isVideoCall)? onStartCall;

  const _CallHistoryTile({
    required this.call,
    required this.currentUserId,
    required this.onStartCall,
  });

  @override
  Widget build(BuildContext context) {
    final isOutgoing = call.callerId == currentUserId;
    final displayName = _otherUserName(call, currentUserId);
    final displayEmail = _otherUserEmail(call, currentUserId);
    final statusColor = _statusColor(call.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _CallAvatar(
            name: displayName,
            icon: call.callType == CallType.video
                ? Icons.videocam_rounded
                : Icons.call_rounded,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(
                      label: _statusLabel(call.status),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  displayEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _CallMeta(
                      icon: isOutgoing
                          ? Icons.call_made_rounded
                          : Icons.call_received_rounded,
                      text: isOutgoing ? 'Outgoing' : 'Incoming',
                    ),
                    _CallMeta(
                      icon: Icons.schedule_rounded,
                      text: _formatCallTime(call.createdAt),
                    ),
                    _CallMeta(
                      icon: Icons.timer_outlined,
                      text: _formatDuration(call.getDurationInSeconds()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              _RoundActionButton(
                icon: Icons.call_rounded,
                color: const Color(0xFF22B61E),
                tooltip: 'Audio call',
                onTap: onStartCall == null
                    ? null
                    : () => onStartCall!(call, false),
              ),
              const SizedBox(height: 8),
              _RoundActionButton(
                icon: Icons.videocam_rounded,
                color: const Color(0xFF3478F6),
                tooltip: 'Video call',
                onTap: onStartCall == null
                    ? null
                    : () => onStartCall!(call, true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallAvatar extends StatelessWidget {
  final String name;
  final IconData icon;

  const _CallAvatar({required this.name, required this.icon});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'U' : name.trim()[0].toUpperCase();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEEE3FF), Color(0xFFD7F7E8)],
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF4B238C),
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF7E3DFF), size: 16),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CallMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CallMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.grey.shade500, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _RoundActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: onTap == null ? Colors.grey.shade300 : color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CallEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _CallEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 130),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: const Color(0xFF7E3DFF)),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _otherUserId(CallModel call, String currentUserId) {
  return call.callerId == currentUserId ? call.receiverId : call.callerId;
}

String _otherUserName(CallModel call, String currentUserId) {
  final name = call.callerId == currentUserId
      ? call.receiverName
      : call.callerName;

  return name.trim().isEmpty ? 'Unknown User' : name;
}

String _otherUserEmail(CallModel call, String currentUserId) {
  final email = call.callerId == currentUserId
      ? call.receiverEmail
      : call.callerEmail;

  return email.trim().isEmpty ? 'No email available' : email;
}

String _formatDuration(int? seconds) {
  if (seconds == null) return 'No duration';
  if (seconds < 60) return '${seconds}s';

  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;

  if (minutes < 60) {
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes}m';
}

String _formatCompactDuration(int seconds) {
  if (seconds <= 0) return '0s';
  if (seconds < 60) return '${seconds}s';

  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return remainingMinutes == 0 ? '${hours}h' : '${hours}h ${remainingMinutes}m';
}

String _formatCallTime(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final callDay = DateTime(date.year, date.month, date.day);
  final time = _formatClockTime(date);

  if (callDay == today) return 'Today, $time';
  if (callDay == today.subtract(const Duration(days: 1))) {
    return 'Yesterday, $time';
  }

  return '${_monthName(date.month)} ${date.day}, $time';
}

String _formatClockTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return months[(month - 1).clamp(0, months.length - 1)];
}

String _statusLabel(CallStatus status) {
  return switch (status) {
    CallStatus.ringing => 'Ringing',
    CallStatus.accepted => 'Live',
    CallStatus.rejected => 'Rejected',
    CallStatus.ended => 'Ended',
    CallStatus.missed => 'Missed',
  };
}

Color _statusColor(CallStatus status) {
  return switch (status) {
    CallStatus.ringing => const Color(0xFF7E3DFF),
    CallStatus.accepted => const Color(0xFF3478F6),
    CallStatus.rejected => const Color(0xFFE03A3A),
    CallStatus.ended => const Color(0xFF19A463),
    CallStatus.missed => const Color(0xFFE58A00),
  };
}
