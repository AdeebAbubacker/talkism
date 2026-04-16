class AppConstants {
  const AppConstants._();

  static const String appName = 'Talkiyo Receiver';
  static const String receiverRole = 'receiver';

  // TODO: Replace with your Agora App ID or pass
  // --dart-define=AGORA_APP_ID=your_app_id while running/building the app.
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

  static const String incomingCallChannelId = 'incoming_calls';
  static const String incomingCallChannelName = 'Incoming Calls';
  static const String incomingCallChannelDescription =
      'Alerts the receiver about incoming audio and video calls.';

  static bool get isAgoraConfigured =>
      agoraAppId.isNotEmpty && agoraAppId != 'YOUR_AGORA_APP_ID';

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
