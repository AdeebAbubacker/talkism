import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType {
  audio,
  video;

  static CallType fromValue(String? value) {
    return value?.toLowerCase() == 'video' ? CallType.video : CallType.audio;
  }

  String get value => name;
}

enum CallDocumentStatus {
  ringing,
  accepted,
  connected,
  rejected,
  ended,
  unknown;

  static CallDocumentStatus fromValue(String? value) {
    return CallDocumentStatus.values.firstWhere(
      (status) => status.value == value?.toLowerCase(),
      orElse: () => CallDocumentStatus.unknown,
    );
  }

  String get value {
    switch (this) {
      case CallDocumentStatus.ringing:
        return 'ringing';
      case CallDocumentStatus.accepted:
        return 'accepted';
      case CallDocumentStatus.connected:
        return 'connected';
      case CallDocumentStatus.rejected:
        return 'rejected';
      case CallDocumentStatus.ended:
        return 'ended';
      case CallDocumentStatus.unknown:
        return 'unknown';
    }
  }
}

class CallModel {
  const CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required this.channelName,
    required this.callType,
    required this.status,
    required this.agoraToken,
    required this.createdAt,
    required this.updatedAt,
  });

  final String callId;
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final String channelName;
  final CallType callType;
  final CallDocumentStatus status;
  final String? agoraToken;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isVideoCall => callType == CallType.video;

  factory CallModel.fromMap(String docId, Map<String, dynamic> map) {
    return CallModel(
      callId: map['callId']?.toString().isNotEmpty == true
          ? map['callId'].toString()
          : docId,
      callerId: map['callerId']?.toString() ?? '',
      callerName: map['callerName']?.toString() ?? 'Unknown caller',
      receiverId: map['receiverId']?.toString() ?? '',
      receiverName: map['receiverName']?.toString() ?? '',
      channelName: map['channelName']?.toString() ?? '',
      callType: CallType.fromValue(map['callType']?.toString()),
      status: CallDocumentStatus.fromValue(map['status']?.toString()),
      agoraToken: map['agoraToken']?.toString(),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  CallModel copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    String? receiverId,
    String? receiverName,
    String? channelName,
    CallType? callType,
    CallDocumentStatus? status,
    String? agoraToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      channelName: channelName ?? this.channelName,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      agoraToken: agoraToken ?? this.agoraToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'channelName': channelName,
      'callType': callType.value,
      'status': status.value,
      'agoraToken': agoraToken,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static DateTime? _parseDate(dynamic value) {
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
