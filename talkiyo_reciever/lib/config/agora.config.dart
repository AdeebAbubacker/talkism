import 'package:talkiyo_reciever/components/config_override.dart';

/// Get your own App ID at https://dashboard.agora.io/
/// App ID: 60c258d1e7dc46fd83ed237c81969e1b
String get appId {
  // You can directly edit this code to return the appId you want.
  return ExampleConfigOverride().getAppId();
}

/// Please refer to https://docs.agora.io/en/Agora%20Platform/token
/// Token generation requires the following credentials:
/// - App ID: 60c258d1e7dc46fd83ed237c81969e1b
/// - Primary Certificate: f8fb7cdb3c104f6b9cfb15cdba618287
String get token {
  // You can directly edit this code to return the token you want.
  return ExampleConfigOverride().getToken();
}

/// Your channel ID
String get channelId {
  // You can directly edit this code to return the channel ID you want.
  return ExampleConfigOverride().getChannelId();
}

/// Your int user ID
const int uid = 0;

/// Your user ID for the screen sharing
const int screenSharingUid = 10;

/// Your string user ID
const String stringUid = '0';
