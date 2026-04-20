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
  final int? durationInSeconds;
  final List<String> participantIds;

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
    this.durationInSeconds,
    List<String>? participantIds,
  }) : participantIds = participantIds ?? [callerId, receiverId];

  /// Create CallModel from Firestore document
  factory CallModel.fromJson(Map<String, dynamic> json, String callId) {
    final callerId = json['callerId'] ?? '';
    final receiverId = json['receiverId'] ?? '';

    return CallModel(
      callId: callId,
      callerId: callerId,
      callerName: json['callerName'] ?? '',
      callerEmail: json['callerEmail'] ?? '',
      receiverId: receiverId,
      receiverName: json['receiverName'] ?? '',
      receiverEmail: json['receiverEmail'] ?? '',
      channelId: json['channelId'] ?? '',
      token: json['token'] ?? '',
      callType: json['callType'] == 'video' ? CallType.video : CallType.audio,
      status: _statusFromString(json['status'] ?? 'ringing'),
      createdAt: _dateTimeFromJson(json['createdAt']) ?? DateTime.now(),
      acceptedAt: _dateTimeFromJson(json['acceptedAt']),
      endedAt: _dateTimeFromJson(json['endedAt']),
      durationInSeconds: _intFromJson(json['durationInSeconds']),
      participantIds: _participantIdsFromJson(
        json['participantIds'],
        callerId,
        receiverId,
      ),
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
      if (durationInSeconds != null) 'durationInSeconds': durationInSeconds,
      'participantIds': participantIds,
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
    int? durationInSeconds,
    List<String>? participantIds,
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
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      participantIds: participantIds ?? this.participantIds,
    );
  }

  /// Get call duration in seconds
  int? getDurationInSeconds() {
    if (durationInSeconds != null) return durationInSeconds;
    if (acceptedAt == null || endedAt == null) return null;
    final seconds = endedAt!.difference(acceptedAt!).inSeconds;
    return seconds < 0 ? 0 : seconds;
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

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static int? _intFromJson(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static List<String> _participantIdsFromJson(
    dynamic value,
    String callerId,
    String receiverId,
  ) {
    if (value is Iterable) {
      final ids = value.whereType<String>().where((id) => id.isNotEmpty);
      if (ids.isNotEmpty) return ids.toSet().toList();
    }

    return {callerId, receiverId}.where((id) => id.isNotEmpty).toList();
  }
}
