import '../core/constants/app_constants.dart';

class CallNotificationPayload {
  const CallNotificationPayload({
    required this.type,
    required this.callId,
    required this.channelName,
    required this.callerId,
    required this.callerName,
    required this.callerPhoneNumber,
    required this.receiverId,
    required this.status,
  });

  final String type;
  final String callId;
  final String channelName;
  final String callerId;
  final String callerName;
  final String callerPhoneNumber;
  final String receiverId;
  final String status;

  bool get isIncomingInvite =>
      type == AppConstants.pushTypeIncomingCall &&
      status == AppConstants.callStatusRinging;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'callId': callId,
      'channelName': channelName,
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoneNumber': callerPhoneNumber,
      'receiverId': receiverId,
      'status': status,
    };
  }

  factory CallNotificationPayload.fromMap(Map<String, dynamic> map) {
    return CallNotificationPayload(
      type: map['type'] as String? ?? '',
      callId: map['callId'] as String? ?? '',
      channelName: map['channelName'] as String? ?? '',
      callerId: map['callerId'] as String? ?? '',
      callerName: map['callerName'] as String? ?? '',
      callerPhoneNumber: map['callerPhoneNumber'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      status: map['status'] as String? ?? '',
    );
  }

  factory CallNotificationPayload.fromJsonMap(Map<String, Object?> map) {
    return CallNotificationPayload.fromMap(
      map.map((key, value) => MapEntry(key, value ?? '')),
    );
  }
}
