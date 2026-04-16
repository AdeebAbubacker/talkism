# Talkiyo Receiver App

Production-style Flutter Receiver App for an audio/video calling system using Firebase Authentication, Firestore, Firebase Cloud Messaging, Agora, and Provider.

## Features

- Email/password signup and login
- Persistent Firebase auth session
- Firestore-backed receiver user profile
- Presence updates with `isOnline`
- FCM token sync to Firestore
- Firestore listener for incoming calls in `calls`
- Foreground and opened-app FCM incoming call handling
- Incoming call screen with Accept / Reject
- Agora audio and video call join flow
- In-call controls for mute, video toggle, camera switch, and leave
- Provider-only business state management

## Project Structure

```text
lib/
  main.dart
  app.dart
  firebase_options.dart

  core/
    constants/
      app_constants.dart
    services/
      agora_service.dart
      auth_service.dart
      firestore_service.dart
      notification_service.dart

  models/
    app_user.dart
    call_model.dart

  providers/
    auth_provider.dart
    receiver_user_provider.dart
    call_provider.dart

  screens/
    auth/
      login_screen.dart
      signup_screen.dart
    splash/
      splash_screen.dart
    home/
      home_screen.dart
    incoming_call/
      incoming_call_screen.dart
    call/
      call_screen.dart

  widgets/
    custom_text_field.dart
    primary_button.dart
```

## Dependencies

Core packages are defined in [pubspec.yaml](/Users/sridharn/Desktop/Talkiyo/talkiyo_reciever/pubspec.yaml).

- `provider`
- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_messaging`
- `flutter_local_notifications`
- `agora_rtc_engine`

## Firestore Data Model

### `users/{uid}`

```json
{
  "uid": "firebase_uid",
  "name": "Receiver Name",
  "email": "receiver@example.com",
  "isOnline": true,
  "role": "receiver",
  "fcmToken": "device_fcm_token",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### `calls/{callId}`

```json
{
  "callId": "document_id",
  "callerId": "caller_uid",
  "callerName": "Caller Name",
  "receiverId": "receiver_uid",
  "receiverName": "Receiver Name",
  "channelName": "unique_channel_name",
  "callType": "audio",
  "status": "ringing",
  "agoraToken": "optional_agora_token",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

Used status values in this app:

- `ringing`
- `accepted`
- `connected`
- `rejected`
- `ended`

## Setup Instructions

### 1. Firebase

1. Create or reuse a Firebase project.
2. Enable Email/Password authentication.
3. Add Android and iOS apps in Firebase.
4. Replace Firebase config if needed:
   - Android: [android/app/google-services.json](/Users/sridharn/Desktop/Talkiyo/talkiyo_reciever/android/app/google-services.json)
   - iOS: [ios/Runner/GoogleService-Info.plist](/Users/sridharn/Desktop/Talkiyo/talkiyo_reciever/ios/Runner/GoogleService-Info.plist)
   - FlutterFire config: [lib/firebase_options.dart](/Users/sridharn/Desktop/Talkiyo/talkiyo_reciever/lib/firebase_options.dart)

### 2. Agora

1. Create an Agora project.
2. The checked-in receiver app is already configured with Agora App ID `3fe512d0a3da45e68d5e16972a82733c` in [lib/core/constants/app_constants.dart](/Users/sridharn/Desktop/Talkiyo/talkiyo_reciever/lib/core/constants/app_constants.dart:8).
3. The local token server config at [tools/agora_token_server/config.local.json](/Users/sridharn/Desktop/Talkiyo/talkiyo_reciever/tools/agora_token_server/config.local.json) already contains the primary and secondary certificates for this Agora project.
4. Start the local token server before testing certificate-protected calls:

```bash
npm run agora-token-server
```

5. If you test on a real device or use a remote backend, pass that backend with `--dart-define=CALL_API_BASE_URL=https://your-server`.

Recommended run command during local testing:

```bash
flutter run
```

### 3. FCM and Notifications

1. Android:
   - Ensure the Firebase app is linked.
   - Keep notification permissions enabled on Android 13+.
2. iOS:
   - Enable Push Notifications capability.
   - Enable Background Modes with `Remote notifications`.
   - Upload an APNs key/certificate in Firebase.
3. The app already initializes FCM and foreground local notifications in [lib/core/services/notification_service.dart](/Users/sridharn/Desktop/Talkiyo/talkiyo_reciever/lib/core/services/notification_service.dart).

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Run

```bash
flutter run
```

## Firestore Rules Suggestion

Example rules are included in [firestore.rules.example](/Users/sridharn/Desktop/Talkiyo/talkiyo_reciever/firestore.rules.example).

These rules are intentionally machine-test friendly, but you should tighten them for production based on your final caller/receiver flow.

## Manual Setup Steps

- Verify your Firebase config files match the package names/bundle IDs.
- Confirm Android and iOS notification permissions are enabled.
- Confirm your caller backend or caller app writes `calls` documents in the expected shape.
- Confirm your FCM sender includes `callId` and `receiverId` in message `data`.
- Start `npm run agora-token-server` if Agora App Certificate protection is enabled.

## Missing Environment / Config Values

You still need to fill in:

- Real Firebase project config if the checked-in one is not yours
- APNs setup for iOS push delivery
- Server-side Agora token generation for shared environments if you do not want to use the local token server
- Caller-side FCM sending logic for incoming calls

## How To Test With A Separate Caller App

1. Register a receiver user in this app and log in.
2. Confirm a matching document exists in `users/{uid}` with `role: "receiver"` and a fresh `fcmToken`.
3. From the Caller App or backend, create a `calls/{callId}` document with:
   - `receiverId` set to the receiver user UID
   - `status: "ringing"`
   - valid `channelName`
   - `callType: "audio"` or `callType: "video"`
   - `agoraToken` if your Agora project requires it
4. Send an FCM data notification to the receiver device including at least:

```json
{
  "type": "incoming_call",
  "callId": "your_call_doc_id",
  "receiverId": "receiver_uid",
  "callerName": "Caller Name",
  "callType": "video"
}
```

5. The Receiver App should:
   - stay logged in
   - show the incoming call UI
   - allow accept or reject
   - join the Agora channel on accept
6. End the call from either app and update Firestore `status` to `ended`.

## Notes

- This app keeps business logic inside Provider classes, not widgets.
- Foreground incoming calls also trigger a local notification for better visibility.
- Presence updates use lifecycle callbacks and logout flow, but mobile OS termination is never perfectly guaranteed for real-time presence systems.
