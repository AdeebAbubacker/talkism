# Talkiyo Caller App

Production-style Flutter caller app for an audio calling system built with:

- Flutter
- Firebase Auth
- Cloud Firestore
- Firebase Cloud Messaging
- Agora RTC
- Provider

This app is the **Caller App** in a two-app setup:

- Caller App: starts calls
- Receiver App: listens for new Firestore call documents and handles incoming calls

## Features

- Email/password signup and login
- Persistent Firebase session
- Firestore-backed caller user profile
- Receiver user list from Firestore
- Audio call creation through `calls` collection
- FCM token capture for the caller user document
- Outgoing call screen that listens to Firestore call status
- Agora audio join after the receiver accepts the call
- Mic mute/unmute, speaker toggle, and leave call controls
- Provider-based state management for auth, users, and calling

## Project Structure

```text
lib/
  app.dart
  main.dart
  firebase_options.dart
  core/
    constants/
      app_constants.dart
    services/
      agora_service.dart
      firestore_service.dart
      notification_service.dart
  models/
    app_user.dart
    call_model.dart
  providers/
    auth_provider.dart
    call_provider.dart
    users_provider.dart
  screens/
    auth/
      login_screen.dart
      signup_screen.dart
    call/
      audio_call_screen.dart
    calling/
      outgoing_call_screen.dart
    splash/
      splash_screen.dart
    users/
      user_list_screen.dart
  widgets/
    custom_text_field.dart
    primary_button.dart
    user_tile.dart
```

## Firebase Setup

1. Create a Firebase project.
2. Enable **Authentication > Email/Password**.
3. Add Android and iOS apps in Firebase.
4. Download and place:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
5. Run FlutterFire if you need to regenerate [lib/firebase_options.dart](/Users/sridharn/Desktop/Talkiyo/talkiyo_caller/lib/firebase_options.dart).
6. Enable **Cloud Firestore**.
7. Enable **Cloud Messaging**.

## Agora Setup

The app expects the Agora App ID through `--dart-define`.

Example:

```bash
flutter run --dart-define=AGORA_APP_ID=YOUR_AGORA_APP_ID
```

If your Agora project uses temporary or server-generated channel tokens, each participant should fetch a token for their own Agora UID right before joining. Do not rely on one shared `agoraToken` value in `calls/{callId}` for both sides, because the caller and receiver typically join with different UIDs.

If your Agora project has an app certificate disabled for testing, `agoraToken` can stay empty.

## Required Environment / Config Values

Fill these values before testing:

- `AGORA_APP_ID`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- Firebase Auth enabled for email/password
- Firestore security rules that allow the caller user to read receiver users and write/update their own call documents

## Firestore Collections

### `users`

Caller app writes caller users like:

```json
{
  "uid": "caller_uid",
  "name": "Caller Name",
  "email": "caller@example.com",
  "isOnline": true,
  "role": "caller",
  "fcmToken": "device_fcm_token",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

Receiver users should already exist with:

```json
{
  "uid": "receiver_uid",
  "name": "Receiver Name",
  "email": "receiver@example.com",
  "isOnline": true,
  "role": "receiver",
  "fcmToken": "receiver_fcm_token"
}
```

### `calls`

Caller app creates documents like:

```json
{
  "callId": "firestore_doc_id",
  "callerId": "caller_uid",
  "callerName": "Caller Name",
  "receiverId": "receiver_uid",
  "receiverName": "Receiver Name",
  "channelName": "audio_firestore_doc_id",
  "callType": "audio",
  "status": "ringing",
  "agoraToken": "",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

Expected status flow:

- `ringing`
- `accepted`
- `rejected`
- `ended`

## Cloud Function / Webhook Expectation

This caller app does **not** send FCM directly.

Expected backend behavior:

1. A new `calls` document is created by the caller app.
2. A Firebase Cloud Function or webhook listens for that document.
3. The function sends an FCM push notification to the receiver.
4. The receiver app reads `callId`, caller info, and opens its incoming call UI.
5. The receiver app updates the Firestore call document status to `accepted`, `rejected`, or `ended`.

## How the Caller App Works

1. Launch app
2. Splash screen checks Firebase session
3. Login or signup if needed
4. Caller Firestore profile is created or updated
5. Caller sees receiver users from `users where role == "receiver"`
6. Caller taps the audio call button
7. App creates `calls/{callId}` with `status = "ringing"`
8. Outgoing call screen listens to the Firestore document
9. When status becomes `accepted`, caller joins Agora audio
10. During the call, caller can mute mic, toggle speaker, and leave

## Testing With Two Devices

Use:

- Device 1: this Caller App
- Device 2: your existing Receiver App

Test flow:

1. Install and run the Receiver App on Device 2.
2. Make sure Receiver App writes a Firestore user document with `role = "receiver"` and a valid `fcmToken`.
3. Run this Caller App on Device 1 with:

```bash
flutter pub get
flutter run --dart-define=AGORA_APP_ID=YOUR_AGORA_APP_ID
```

4. Create or log into a caller account.
5. Confirm the caller user is written to Firestore with `role = "caller"`.
6. Verify the receiver appears in the user list.
7. Tap the call button for that receiver.
8. Confirm a `calls` document is created in Firestore with `status = "ringing"`.
9. Confirm your backend sends an FCM notification to the Receiver App.
10. Accept the call on Device 2.
11. Confirm Device 1 moves from outgoing call screen to audio call screen.
12. Verify both devices join the same Agora `channelName`.
13. Test mute, speaker toggle, and leave call.
14. End the call from either side and confirm `status = "ended"`.

## Receiver App Contract

For this caller app to work smoothly, the Receiver App should:

- listen to new `calls` documents for its `receiverId`
- show incoming call UI
- update `status` to `accepted`, `rejected`, or `ended`
- keep `agoraToken` empty unless you intentionally support a legacy shared-token flow
- join the same `channelName`

## Notes

- Presence updates are best-effort through lifecycle events and logout.
- The app uses Provider for app/business state and avoids `setState` for business logic.
- The current Firebase config file in this repo already points to one Firebase project, but you should still verify it matches your intended Android/iOS app IDs.
