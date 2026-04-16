class AppConstants {
  const AppConstants._();

  static const String usersCollection = 'users';
  static const String callsCollection = 'calls';
  static const String defaultDialerChannel = 'talkiyo/default_dialer';
  static const String incomingCallNotificationChannelId =
      'talkiyo_incoming_calls';
  static const String incomingCallNotificationChannelName =
      'Incoming Talkiyo Calls';
  static const String incomingCallNotificationChannelDescription =
      'Heads-up notifications for active incoming Talkiyo calls.';
  static const Duration defaultCallRingTimeout = Duration(seconds: 30);

  static const String userRole = 'user';
  static const String callerRole = 'caller';
  static const String receiverRole = 'receiver';
  static const String audioCallType = 'audio';

  static const String callStatusRinging = 'ringing';
  static const String callStatusAccepted = 'accepted';
  static const String callStatusRejected = 'rejected';
  static const String callStatusCancelled = 'cancelled';
  static const String callStatusBusy = 'busy';
  static const String callStatusMissed = 'missed';
  static const String callStatusTimeout = 'timeout';
  static const String callStatusEnded = 'ended';
  static const String pushTypeIncomingCall = 'incoming_call';
  static const String pushTypeCallState = 'call_state';

  static const String agoraAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: '3fe512d0a3da45e68d5e16972a82733c',
  );
  static const String agoraRtcToken = String.fromEnvironment(
    'AGORA_RTC_TOKEN',
    defaultValue: '',
  );
  static const String agoraActiveCertificate = String.fromEnvironment(
    'AGORA_ACTIVE_CERTIFICATE',
    defaultValue: 'primary',
  );
  static const String agoraPrimaryCertificate = String.fromEnvironment(
    'AGORA_APP_CERTIFICATE_PRIMARY',
    defaultValue: '029308d9201743758b73eecbef8b3ebc',
  );
  static const String agoraSecondaryCertificate = String.fromEnvironment(
    'AGORA_APP_CERTIFICATE_SECONDARY',
    defaultValue: 'b88d787b070449cca1cbd294d11646f6',
  );
  static const int agoraTokenTtlSeconds = int.fromEnvironment(
    'AGORA_TOKEN_TTL_SECONDS',
    defaultValue: 3600,
  );
  static const String callApiBaseUrl = String.fromEnvironment(
    'CALL_API_BASE_URL',
    defaultValue: '',
  );

  static String get agoraAppCertificate {
    if (agoraActiveCertificate == 'secondary' &&
        agoraSecondaryCertificate.trim().isNotEmpty) {
      return agoraSecondaryCertificate.trim();
    }

    if (agoraPrimaryCertificate.trim().isNotEmpty) {
      return agoraPrimaryCertificate.trim();
    }

    return agoraSecondaryCertificate.trim();
  }
}
