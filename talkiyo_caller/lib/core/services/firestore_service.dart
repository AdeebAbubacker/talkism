import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../models/call_model.dart';
import '../constants/app_constants.dart';

class FirestoreService {
  FirestoreService._(this._firestore);

  static final FirestoreService instance = FirestoreService._(
    FirebaseFirestore.instance,
  );

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(AppConstants.usersCollection);

  CollectionReference<Map<String, dynamic>> get _callsCollection =>
      _firestore.collection(AppConstants.callsCollection);

  Stream<List<AppUser>> streamAvailableUsers({required String currentUserId}) {
    return _usersCollection
        .where('role', isEqualTo: AppConstants.receiverRole)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AppUser.fromMap(doc.data()))
                  .where((user) => user.uid != currentUserId)
                  .toList()
                ..sort((first, second) {
                  if (first.isOnline == second.isOnline) {
                    return first.displayName.toLowerCase().compareTo(
                      second.displayName.toLowerCase(),
                    );
                  }

                  return first.isOnline ? -1 : 1;
                }),
        );
  }

  Future<AppUser> upsertCallerUser({
    required String uid,
    required String email,
    required String name,
    required String phoneNumber,
    required bool isOnline,
    required String fcmToken,
  }) async {
    final docRef = _usersCollection.doc(uid);
    Map<String, dynamic>? data;

    try {
      final snapshot = await docRef.get();
      data = snapshot.data();
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        rethrow;
      }
    }

    final resolvedName = name.trim().isNotEmpty
        ? name.trim()
        : (data?['name'] as String?)?.trim().isNotEmpty == true
        ? (data?['name'] as String).trim()
        : email.split('@').first;
    final resolvedPhoneNumber = phoneNumber.trim().isNotEmpty
        ? phoneNumber.trim()
        : (data?['phoneNumber'] as String?)?.trim() ?? '';

    await docRef.set({
      'uid': uid,
      'name': resolvedName,
      'email': email,
      'phoneNumber': resolvedPhoneNumber,
      'isOnline': isOnline,
      'role': AppConstants.callerRole,
      'fcmToken': fcmToken,
      'createdAt': data?['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return AppUser(
      uid: uid,
      name: resolvedName,
      email: email,
      phoneNumber: resolvedPhoneNumber,
      isOnline: isOnline,
      role: AppConstants.callerRole,
      fcmToken: fcmToken,
      createdAt: data == null
          ? DateTime.now()
          : AppUser.fromMap(data).createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> updateUserOnlineStatus({
    required String uid,
    required bool isOnline,
  }) {
    return _usersCollection.doc(uid).set({
      'uid': uid,
      'role': AppConstants.callerRole,
      'isOnline': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserFcmToken({
    required String uid,
    required String fcmToken,
  }) {
    return _usersCollection.doc(uid).set({
      'uid': uid,
      'role': AppConstants.callerRole,
      'fcmToken': fcmToken,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<CallModel?> fetchCall(String callId) async {
    final snapshot = await _callsCollection.doc(callId).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    return CallModel.fromMap(data);
  }

  Future<CallModel> createAudioCall({
    required AppUser caller,
    required AppUser receiver,
    required String callerDeviceId,
    Duration ringTimeout = AppConstants.defaultCallRingTimeout,
    String agoraToken = '',
  }) async {
    final docRef = _callsCollection.doc();
    final now = DateTime.now();
    final call = CallModel(
      callId: docRef.id,
      callerId: caller.uid,
      callerName: caller.displayName,
      callerPhoneNumber: caller.phoneNumber,
      callerDeviceId: callerDeviceId,
      receiverId: receiver.uid,
      receiverName: receiver.displayName,
      receiverPhoneNumber: receiver.phoneNumber,
      channelName: 'audio_${docRef.id}',
      callType: AppConstants.audioCallType,
      status: AppConstants.callStatusRinging,
      agoraToken: agoraToken.trim(),
      createdAt: now,
      updatedAt: now,
      ringTimeoutAt: now.add(ringTimeout),
    );

    await docRef.set({
      ...call.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'ringTimeoutAt': Timestamp.fromDate(call.ringTimeoutAt!),
    });

    return call;
  }

  Stream<CallModel?> watchCall(String callId) {
    return _callsCollection.doc(callId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      return CallModel.fromMap(data);
    });
  }

  Stream<CallModel?> watchIncomingCall(String receiverId) {
    return _callsCollection
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: AppConstants.callStatusRinging)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }

          final calls =
              snapshot.docs.map((doc) => CallModel.fromMap(doc.data())).toList()
                ..sort((first, second) {
                  final secondTime =
                      second.updatedAt ?? second.createdAt ?? DateTime(0);
                  final firstTime =
                      first.updatedAt ?? first.createdAt ?? DateTime(0);
                  return secondTime.compareTo(firstTime);
                });
          return calls.first;
        });
  }

  Future<void> updateCallStatus({
    required String callId,
    required String status,
    String? agoraToken,
    String? acceptedByDeviceId,
    String? endReason,
    DateTime? answeredAt,
    DateTime? endedAt,
  }) {
    final payload = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (agoraToken != null) {
      payload['agoraToken'] = agoraToken;
    }

    if (acceptedByDeviceId != null) {
      payload['acceptedByDeviceId'] = acceptedByDeviceId;
    }

    if (endReason != null) {
      payload['endReason'] = endReason;
    }

    if (answeredAt != null) {
      payload['answeredAt'] = Timestamp.fromDate(answeredAt);
    }

    if (endedAt != null) {
      payload['endedAt'] = Timestamp.fromDate(endedAt);
    }

    return _callsCollection.doc(callId).set(payload, SetOptions(merge: true));
  }

  Future<CallModel?> acceptIncomingCall({
    required String callId,
    required String deviceId,
  }) async {
    return _firestore.runTransaction<CallModel?>((transaction) async {
      final docRef = _callsCollection.doc(callId);
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      final currentCall = CallModel.fromMap(data);
      if (currentCall.status != AppConstants.callStatusRinging) {
        return currentCall;
      }

      final answeredAt = DateTime.now();
      transaction.set(docRef, {
        'status': AppConstants.callStatusAccepted,
        'acceptedByDeviceId': deviceId,
        'answeredAt': Timestamp.fromDate(answeredAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return currentCall.copyWith(
        status: AppConstants.callStatusAccepted,
        acceptedByDeviceId: deviceId,
        answeredAt: answeredAt,
      );
    });
  }

  Future<void> markCallTerminal({
    required String callId,
    required String status,
    required String reason,
  }) {
    return updateCallStatus(
      callId: callId,
      status: status,
      endReason: reason,
      endedAt: DateTime.now(),
    );
  }

  Future<void> markCallTimedOutIfStillRinging(String callId) async {
    await _firestore.runTransaction((transaction) async {
      final docRef = _callsCollection.doc(callId);
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      if (data == null) {
        return;
      }

      final call = CallModel.fromMap(data);
      if (call.status != AppConstants.callStatusRinging) {
        return;
      }

      final timeoutAt = call.ringTimeoutAt;
      if (timeoutAt != null && timeoutAt.isAfter(DateTime.now())) {
        return;
      }

      transaction.set(docRef, {
        'status': AppConstants.callStatusTimeout,
        'endReason': AppConstants.callStatusTimeout,
        'endedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
