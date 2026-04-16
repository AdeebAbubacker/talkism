import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';

class CallModel {
  const CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerPhoneNumber,
    required this.callerDeviceId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhoneNumber,
    required this.channelName,
    required this.callType,
    required this.status,
    required this.agoraToken,
    this.acceptedByDeviceId,
    this.endReason,
    this.createdAt,
    this.updatedAt,
    this.ringTimeoutAt,
    this.answeredAt,
    this.endedAt,
  });

  final String callId;
  final String callerId;
  final String callerName;
  final String callerPhoneNumber;
  final String callerDeviceId;
  final String receiverId;
  final String receiverName;
  final String receiverPhoneNumber;
  final String channelName;
  final String callType;
  final String status;
  final String agoraToken;
  final String? acceptedByDeviceId;
  final String? endReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? ringTimeoutAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  bool get isTerminal =>
      status == AppConstants.callStatusRejected ||
      status == AppConstants.callStatusCancelled ||
      status == AppConstants.callStatusBusy ||
      status == AppConstants.callStatusMissed ||
      status == AppConstants.callStatusTimeout ||
      status == AppConstants.callStatusEnded;

  CallModel copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerPhoneNumber,
    String? callerDeviceId,
    String? receiverId,
    String? receiverName,
    String? receiverPhoneNumber,
    String? channelName,
    String? callType,
    String? status,
    String? agoraToken,
    String? acceptedByDeviceId,
    String? endReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? ringTimeoutAt,
    DateTime? answeredAt,
    DateTime? endedAt,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerPhoneNumber: callerPhoneNumber ?? this.callerPhoneNumber,
      callerDeviceId: callerDeviceId ?? this.callerDeviceId,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverPhoneNumber: receiverPhoneNumber ?? this.receiverPhoneNumber,
      channelName: channelName ?? this.channelName,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      agoraToken: agoraToken ?? this.agoraToken,
      acceptedByDeviceId: acceptedByDeviceId ?? this.acceptedByDeviceId,
      endReason: endReason ?? this.endReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ringTimeoutAt: ringTimeoutAt ?? this.ringTimeoutAt,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoneNumber': callerPhoneNumber,
      'callerDeviceId': callerDeviceId,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhoneNumber': receiverPhoneNumber,
      'channelName': channelName,
      'callType': callType,
      'status': status,
      'agoraToken': agoraToken,
      'acceptedByDeviceId': acceptedByDeviceId,
      'endReason': endReason,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'ringTimeoutAt': ringTimeoutAt,
      'answeredAt': answeredAt,
      'endedAt': endedAt,
    };
  }

  factory CallModel.fromMap(Map<String, dynamic> map) {
    return CallModel(
      callId: map['callId'] as String? ?? '',
      callerId: map['callerId'] as String? ?? '',
      callerName: map['callerName'] as String? ?? '',
      callerPhoneNumber: map['callerPhoneNumber'] as String? ?? '',
      callerDeviceId: map['callerDeviceId'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      receiverName: map['receiverName'] as String? ?? '',
      receiverPhoneNumber: map['receiverPhoneNumber'] as String? ?? '',
      channelName: map['channelName'] as String? ?? '',
      callType: map['callType'] as String? ?? '',
      status: map['status'] as String? ?? '',
      agoraToken: map['agoraToken'] as String? ?? '',
      acceptedByDeviceId: map['acceptedByDeviceId'] as String?,
      endReason: map['endReason'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      ringTimeoutAt: _parseDateTime(map['ringTimeoutAt']),
      answeredAt: _parseDateTime(map['answeredAt']),
      endedAt: _parseDateTime(map['endedAt']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
