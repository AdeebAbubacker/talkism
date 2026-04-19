import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for call types
enum CallType { audio, video }

/// Enum for call status
enum CallStatus { ringing, accepted, rejected, ended, missed }

/// Call model representing a call between two users
class CallModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerEmail;
  final String receiverId;
  final String receiverName;
  final String receiverEmail;
  final String channelId;
  final String token;
  final CallType callType;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;

  CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerEmail,
    required this.receiverId,
    required this.receiverName,
    required this.receiverEmail,
    required this.channelId,
    required this.token,
    required this.callType,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.endedAt,
  });

  /// Create CallModel from Firestore document
  factory CallModel.fromJson(Map<String, dynamic> json, String callId) {
    return CallModel(
      callId: callId,
      callerId: json['callerId'] ?? '',
      callerName: json['callerName'] ?? '',
      callerEmail: json['callerEmail'] ?? '',
      receiverId: json['receiverId'] ?? '',
      receiverName: json['receiverName'] ?? '',
      receiverEmail: json['receiverEmail'] ?? '',
      channelId: json['channelId'] ?? '',
      token: json['token'] ?? '',
      callType: json['callType'] == 'video' ? CallType.video : CallType.audio,
      status: _statusFromString(json['status'] ?? 'ringing'),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (json['acceptedAt'] as Timestamp?)?.toDate(),
      endedAt: (json['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert CallModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerEmail': callerEmail,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverEmail': receiverEmail,
      'channelId': channelId,
      'token': token,
      'callType': callType == CallType.video ? 'video' : 'audio',
      'status': _statusToString(status),
      'createdAt': createdAt,
      'acceptedAt': acceptedAt,
      'endedAt': endedAt,
    };
  }

  /// Create a copy of CallModel with optional updates
  CallModel copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerEmail,
    String? receiverId,
    String? receiverName,
    String? receiverEmail,
    String? channelId,
    String? token,
    CallType? callType,
    CallStatus? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? endedAt,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerEmail: callerEmail ?? this.callerEmail,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverEmail: receiverEmail ?? this.receiverEmail,
      channelId: channelId ?? this.channelId,
      token: token ?? this.token,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  /// Get call duration in seconds
  int? getDurationInSeconds() {
    if (acceptedAt == null || endedAt == null) return null;
    return endedAt!.difference(acceptedAt!).inSeconds;
  }

  /// Helper to convert CallStatus enum to string
  static String _statusToString(CallStatus status) {
    return status.toString().split('.').last;
  }

  /// Helper to convert string to CallStatus enum
  static CallStatus _statusFromString(String status) {
    switch (status) {
      case 'accepted':
        return CallStatus.accepted;
      case 'rejected':
        return CallStatus.rejected;
      case 'ended':
        return CallStatus.ended;
      case 'missed':
        return CallStatus.missed;
      default:
        return CallStatus.ringing;
    }
  }
}
