import 'package:talkiyo_caller/utils/agora_token_generator.dart';

/// Key of APP ID
const keyAppId = 'TEST_APP_ID';

/// Key of Channel ID
const keyChannelId = 'TEST_CHANNEL_ID';

/// Key of token
const keyToken = 'TEST_TOKEN';

/// Agora App ID: 60c258d1e7dc46fd83ed237c81969e1b
/// Primary Certificate: f8fb7cdb3c104f6b9cfb15cdba618287
const String agoraAppId = '60c258d1e7dc46fd83ed237c81969e1b';
const String agoraPrimaryCertificate = 'f8fb7cdb3c104f6b9cfb15cdba618287';

ExampleConfigOverride? _gConfigOverride;

/// This class allow override the config(appId/channelId/token) in the example.
class ExampleConfigOverride {
  ExampleConfigOverride._();

  factory ExampleConfigOverride() {
    _gConfigOverride = _gConfigOverride ?? ExampleConfigOverride._();
    return _gConfigOverride!;
  }
  final Map<String, String> _overridedConfig = {};

  /// Get the expected APP ID
  String getAppId() {
    return _overridedConfig[keyAppId] ??
        // Allow pass an `appId` as an environment variable with name `TEST_APP_ID` by using --dart-define
        const String.fromEnvironment(keyAppId, defaultValue: agoraAppId);
  }

  /// Get the expected Channel ID
  String getChannelId() {
    return _overridedConfig[keyChannelId] ??
        // Allow pass a `channelId` as an environment variable with name `TEST_CHANNEL_ID` by using --dart-define
        const String.fromEnvironment(keyChannelId,
            defaultValue: 'talksim'); // your channel
  }

  /// Get the expected Token
  String getToken() {
    final configuredToken =
        _overridedConfig[keyToken] ?? const String.fromEnvironment(keyToken);
    if (configuredToken.isNotEmpty) {
      return configuredToken;
    }

    return AgoraTokenGenerator.generateRtcToken(
      appId: getAppId(),
      appCertificate: agoraPrimaryCertificate,
      channelName: getChannelId(),
    );
  }

  /// Override the config(appId/channelId/token)
  void set(String name, String value) {
    _overridedConfig[name] = value;
  }

  /// Internal testing flag
  bool get isInternalTesting =>
      const bool.fromEnvironment('INTERNAL_TESTING', defaultValue: false);
}
