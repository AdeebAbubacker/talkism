# Agora Incoming Call Flow

## Important

Agora RTC handles media transport only. It does **not** wake the receiver app from a killed state by itself.

For real incoming call behavior you need:

- A signaling/backend layer that creates and updates call invitations
- Firebase Cloud Messaging for Android push delivery
- PushKit + CallKit on iOS for true VoIP-style incoming calls
- A secure backend-generated Agora RTC token per call and per participant

The Flutter app in this repo now covers:

- in-app incoming call UI when the app is foregrounded
- Android notification tap handling with FCM payload parsing
- call state coordination using Firestore + Provider
- Agora join/leave lifecycle after accept/end
- duplicate `callId` protection and multi-device acceptance cleanup

The remaining production work outside Flutter is:

- backend endpoint implementation
- Android FCM sender
- iOS PushKit + CallKit native bridge
- secure token generation service

## Folder Structure

```text
lib/
  app.dart
  main.dart
  controllers/
    call_controller.dart
  core/
    constants/
      app_constants.dart
    services/
      agora_service.dart
      call_service.dart
      default_dialer_service.dart
      firestore_service.dart
      installation_service.dart
      notification_service.dart
  models/
    app_user.dart
    call_model.dart
    call_notification_payload.dart
  providers/
    auth_provider.dart
    users_provider.dart
  screens/
    auth/
      login_screen.dart
      signup_screen.dart
    call/
      active_call_screen.dart
    calling/
      incoming_call_screen.dart
      outgoing_call_screen.dart
    splash/
      splash_screen.dart
    users/
      user_list_screen.dart
  widgets/
    custom_text_field.dart
    primary_button.dart
    user_tile.dart

docs/
  agora_incoming_call_flow.md
```

## Core Runtime Flow

1. Caller A selects receiver B.
2. `CallController.startOutgoingCall()` creates a `calls/{callId}` document through `CallService`.
3. Backend sends push notifications to all active device tokens for receiver B.
4. If receiver app is foregrounded:
   - Firestore listener and/or FCM foreground event reaches `CallController`
   - app opens `IncomingCallScreen`
5. If receiver app is backgrounded or terminated on Android:
   - backend sends high-priority FCM notification + data payload
   - user taps notification
   - `NotificationService` parses payload via `getInitialMessage()` or `onMessageOpenedApp`
   - `CallController` fetches the latest call document and opens incoming UI
6. Receiver accepts:
   - `CallController.acceptIncomingCall()` performs a transactional Firestore accept
   - call status becomes `accepted`
   - `acceptedByDeviceId` is stored
   - both sides join the same Agora `channelName`
7. Receiver rejects, caller cancels, call times out, or either side ends:
   - terminal call status is written
   - local notifications are cancelled
   - Agora channel is left safely

## Important Identifiers

- `appUserId`: Firebase-authenticated app user ID
- `callId`: unique Firestore call document ID
- `channelName`: unique Agora channel for this call
- `callerId`: user ID of caller
- `receiverId`: user ID of receiver
- `callerDeviceId`: installation ID for the caller device
- `acceptedByDeviceId`: installation ID of the device that answered

## Multi-Device Strategy

If the same receiver account is active on multiple devices:

- backend sends the same incoming `callId` to all receiver device tokens
- all devices may ring initially
- only one device can accept because `FirestoreService.acceptIncomingCall()` uses a transaction
- the first device sets:
  - `status = accepted`
  - `acceptedByDeviceId = <installationId>`
- other devices watching the same call document stop ringing and show `Answered on another device.`

This is the key pattern that prevents two devices from joining the same incoming answer flow.

## Duplicate Ring Prevention

`CallController` keeps a `_seenIncomingCallIds` set and ignores repeated events for the same `callId`.

This protects against:

- duplicated FCM deliveries
- Firestore snapshot retries
- notification-tap + live-snapshot race conditions

## Call States

The app currently supports these states:

- `ringing`
- `accepted`
- `rejected`
- `cancelled`
- `busy`
- `timeout`
- `missed`
- `ended`

Recommended state meaning:

- `ringing`: invite created, receiver not answered yet
- `accepted`: one receiver device accepted
- `rejected`: receiver explicitly declined
- `cancelled`: caller ended before answer
- `busy`: receiver already had another active or pending call
- `timeout`: nobody answered before `ringTimeoutAt`
- `missed`: optional receiver-side derivative view of a timed-out call
- `ended`: active call ended normally

## Where The Exact Flutter Logic Lives

### Receiving push payload and parsing call data

- `lib/core/services/notification_service.dart`
  - `firebaseMessagingBackgroundHandler`
  - `_handleForegroundMessage`
  - `_handleOpenedMessage`
  - `_parseCallPayload`

### Opening incoming call UI from push or live call state

- `lib/controllers/call_controller.dart`
  - `_handleNotificationPayload`
  - `_ingestIncomingCall`

### Joining Agora after accept

- `lib/controllers/call_controller.dart`
  - `acceptIncomingCall`
  - `_joinAcceptedCall`
- `lib/core/services/call_service.dart`
  - `joinAudioCall`

### Leaving Agora and cleaning up

- `lib/controllers/call_controller.dart`
  - `leaveCall`
  - `_transitionToTerminal`
- `lib/core/services/call_service.dart`
  - `leaveChannel`

## Android FCM Integration

### Backend send requirements

For Android background/terminated incoming call notifications, the backend should send a **high-priority** FCM message with both:

- a notification block for system display
- a data block for `callId`, `channelName`, caller info, and status parsing

Firebase’s Flutter docs note that notification taps are handled through:

- `FirebaseMessaging.instance.getInitialMessage()`
- `FirebaseMessaging.onMessageOpenedApp`

Official Firebase doc:
- https://firebase.google.com/docs/cloud-messaging/flutter/first-message

### Example Android incoming-call payload

```json
{
  "message": {
    "token": "receiver_fcm_token",
    "android": {
      "priority": "high",
      "notification": {
        "channel_id": "talkiyo_incoming_calls",
        "sound": "default",
        "priority": "PRIORITY_HIGH"
      }
    },
    "notification": {
      "title": "Caller One",
      "body": "Incoming Talkiyo call"
    },
    "data": {
      "type": "incoming_call",
      "callId": "call_123",
      "channelName": "audio_call_123",
      "callerId": "user_a",
      "callerName": "Caller One",
      "callerPhoneNumber": "+919876543210",
      "receiverId": "user_b",
      "status": "ringing"
    }
  }
}
```

### Android app-side notes

- `main.dart` registers `FirebaseMessaging.onBackgroundMessage(...)`
- `NotificationService` initializes:
  - FCM permissions
  - local notification channel
  - notification tap callbacks
- `UserListScreen` opens `IncomingCallScreen` whenever `CallController.hasIncomingCall` becomes true

### Android platform notes

- Android 14 adds tighter full-screen intent policy for apps that are not genuine calling/alarm apps
- if you later add a full-screen incoming call experience, verify full-screen intent eligibility and Play policy

Android platform reference:
- https://source.android.com/docs/core/permissions/fsi-limits

FCM high-priority guidance:
- https://firebase.google.com/docs/cloud-messaging/doc-revamp/optimize-delivery/android-message-priority

## iOS PushKit + CallKit Integration Notes

The current Flutter code is structured so the call lifecycle already exists, but **real iOS incoming call behavior for a terminated app still requires native VoIP work**.

### You still need on iOS

- PushKit VoIP certificate / APNs VoIP token flow
- CallKit presentation of the incoming call
- native bridge from PushKit/CallKit into Flutter or shared call state
- Apple-compliant VoIP usage for actual call delivery only

### Recommended native flow

1. App registers for PushKit VoIP token.
2. Backend stores the VoIP token per device.
3. Backend sends a VoIP push when call invite is created.
4. Native iOS layer receives PushKit push.
5. Native layer presents CallKit incoming call UI immediately.
6. On accept/reject:
   - native code calls into Flutter or directly updates backend
   - Flutter `CallController` attaches to the same `callId`
   - app fetches secure Agora RTC token
   - app joins Agora channel

### Flutter integration points already ready

- `CallController._handleNotificationPayload`
- `CallController.acceptIncomingCall`
- `CallController._joinAcceptedCall`
- `CallService.fetchCall`

### Apple references

- PushKit: https://developer.apple.com/documentation/pushkit
- CallKit: https://developer.apple.com/documentation/callkit

## Backend API Contract

The app code can keep Firestore as the real-time state store, but production security still requires a backend API for invite creation, push delivery, and Agora token minting.

### `POST /calls/createCallInvite`

Request:

```json
{
  "callerId": "user_a",
  "callerDeviceId": "device_a1",
  "receiverId": "user_b",
  "callType": "audio"
}
```

Response:

```json
{
  "callId": "call_123",
  "channelName": "audio_call_123",
  "status": "ringing",
  "ringTimeoutAt": "2026-04-16T12:00:30.000Z"
}
```

### `POST /calls/sendPushToReceiver`

Request:

```json
{
  "callId": "call_123",
  "receiverId": "user_b",
  "channelName": "audio_call_123",
  "caller": {
    "callerId": "user_a",
    "callerName": "Caller One",
    "callerPhoneNumber": "+919876543210"
  }
}
```

Response:

```json
{
  "ok": true,
  "sentToDevices": 2
}
```

### `POST /calls/acceptCall`

Request:

```json
{
  "callId": "call_123",
  "receiverId": "user_b",
  "receiverDeviceId": "device_b2"
}
```

Response:

```json
{
  "callId": "call_123",
  "status": "accepted",
  "acceptedByDeviceId": "device_b2"
}
```

### `POST /calls/rejectCall`

Request:

```json
{
  "callId": "call_123",
  "receiverId": "user_b",
  "receiverDeviceId": "device_b2"
}
```

Response:

```json
{
  "callId": "call_123",
  "status": "rejected"
}
```

### `POST /calls/endCall`

Request:

```json
{
  "callId": "call_123",
  "endedByUserId": "user_a"
}
```

Response:

```json
{
  "callId": "call_123",
  "status": "ended"
}
```

### `POST /agora/fetchAgoraRtcToken`

Request:

```json
{
  "callId": "call_123",
  "channelName": "audio_call_123",
  "appUserId": "user_b",
  "participantDeviceId": "device_b2",
  "agoraUid": 123456789
}
```

Response:

```json
{
  "rtcToken": "backend_generated_secure_token",
  "expiresAt": "2026-04-16T12:10:00.000Z"
}
```

## Why One Hardcoded Agora Token Is Not Enough

Do **not** use one hardcoded RTC token for all users in production.

Problems:

- token expiry breaks future calls
- token can leak and be reused across users
- token may not be valid for all channels
- token cannot safely express per-user/per-channel permissions

Production token flow:

1. caller creates invite
2. backend creates `callId` and `channelName`
3. when a participant is about to join, backend mints a token for:
   - specific `channelName`
   - specific Agora UID
   - short expiry window
4. backend returns the token to the joining participant, or stores it in a participant-specific field instead of one shared call token
5. Flutter joins Agora with that token

Agora authentication references:
- https://docs.agora.io/en/
- https://agoraio.zendesk.com/hc/en-us/articles/43231709480468-Locating-App-Secret-and-the-Difference-Between-App-Secret-and-App-Certificate

## Navigation Handling

App open from notification tap is handled by:

- `FirebaseMessaging.instance.getInitialMessage()` for terminated launch
- `FirebaseMessaging.onMessageOpenedApp` for background launch
- `NotificationService` converts the payload into `CallNotificationPayload`
- `CallController` fetches the latest `CallModel`
- `UserListScreen` observes `hasIncomingCall` and opens `IncomingCallScreen`

## Sample Call State Event Payload

```json
{
  "type": "call_state",
  "callId": "call_123",
  "channelName": "audio_call_123",
  "callerId": "user_a",
  "callerName": "Caller One",
  "callerPhoneNumber": "+919876543210",
  "receiverId": "user_b",
  "status": "accepted"
}
```

## Timeout, Busy, Missed, And Cancel-Before-Answer

### Timeout

- each call document stores `ringTimeoutAt`
- `CallController` schedules a local timeout check
- `FirestoreService.markCallTimedOutIfStillRinging()` updates the call to `timeout`
- production recommendation: backend should enforce timeout authoritatively

### Busy

- if receiver already has another pending or active call, `CallController` marks the new call `busy`

### Missed

- receiver side can map a terminal `timeout` into a missed-call UI state
- backend may also persist a separate missed-call history record if needed

### Cancel-before-answer

- caller ends while call is still `ringing`
- state becomes `cancelled`
- receiver UI stops immediately

## Local Two-Device Testing

1. Use two physical devices.
2. Log in as two different Talkiyo users.
3. Make sure each device writes its user document and FCM token.
4. Start the app on both devices.
5. Device A calls Device B.
6. Verify on Device B:
   - foreground: `IncomingCallScreen` opens inside app
   - background: Android push notification appears
   - terminated: tapping Android notification opens app and incoming screen
7. Accept on Device B.
8. Verify both devices join the same Agora `channelName`.
9. Mute/unmute and speaker toggle on one side.
10. End the call from either device.
11. Verify:
   - call status becomes terminal
   - notification disappears
   - both sides leave Agora cleanly

### Multi-device test

1. Sign the same receiver account into Device B and Device C.
2. Call that receiver from Device A.
3. Confirm B and C both ring.
4. Accept on B.
5. Confirm C stops ringing with `Answered on another device.`

## Production Recommendation Summary

- Keep Firestore or your backend as signaling state
- Send FCM from backend, not client
- Use PushKit + CallKit for iOS terminated incoming calls
- Generate Agora tokens on backend per `callId/channelName/agoraUid`
- Use transactional accept logic so one receiver device wins
- Always clean up notification + channel state on every terminal outcome
