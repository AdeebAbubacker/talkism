import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_constants.dart';
import '../../models/app_user.dart';
import '../../models/call_model.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _callsCollection =>
      _firestore.collection('calls');

  Future<void> createOrUpdateReceiverUser({
    required User firebaseUser,
    String? name,
    String? fcmToken,
    bool isOnline = true,
  }) async {
    final docRef = _usersCollection.doc(firebaseUser.uid);
    final snapshot = await docRef.get();
    final existingData = snapshot.data();

    final fallbackName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : (firebaseUser.displayName?.trim().isNotEmpty == true
              ? firebaseUser.displayName!.trim()
              : firebaseUser.email?.split('@').first ?? 'Receiver');

    await docRef.set({
      'uid': firebaseUser.uid,
      'name': fallbackName,
      'email': firebaseUser.email ?? '',
      'isOnline': isOnline,
      'role': AppConstants.receiverRole,
      'fcmToken': fcmToken,
      'createdAt': existingData?['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<AppUser?> watchUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return AppUser.fromMap(snapshot.data()!);
    });
  }

  Future<void> updateUserOnlineStatus(String uid, bool isOnline) {
    return _usersCollection.doc(uid).set({
      'uid': uid,
      'role': AppConstants.receiverRole,
      'isOnline': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserFcmToken(String uid, String? fcmToken) {
    return _usersCollection.doc(uid).set({
      'uid': uid,
      'role': AppConstants.receiverRole,
      'fcmToken': fcmToken,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<CallModel?> acceptIncomingCall({
    required String callId,
    required String deviceId,
  }) {
    return _firestore.runTransaction<CallModel?>((transaction) async {
      final docRef = _callsCollection.doc(callId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      final currentCall = CallModel.fromMap(snapshot.id, snapshot.data()!);
      if (currentCall.status != CallDocumentStatus.ringing) {
        return currentCall;
      }

      transaction.set(docRef, {
        'status': CallDocumentStatus.accepted.value,
        'acceptedByDeviceId': deviceId,
        'answeredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return currentCall.copyWith(status: CallDocumentStatus.accepted);
    });
  }

  Stream<CallModel?> listenForIncomingCalls(String receiverId) {
    return _callsCollection
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: CallDocumentStatus.ringing.value)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }

          final calls =
              snapshot.docs
                  .map((doc) => CallModel.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort(
                  (a, b) =>
                      (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                          .compareTo(
                            a.createdAt ??
                                DateTime.fromMillisecondsSinceEpoch(0),
                          ),
                );

          return calls.first;
        });
  }

  Stream<CallModel?> watchCall(String callId) {
    return _callsCollection.doc(callId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return CallModel.fromMap(snapshot.id, snapshot.data()!);
    });
  }

  Future<CallModel?> fetchCallById(String callId) async {
    final snapshot = await _callsCollection.doc(callId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return CallModel.fromMap(snapshot.id, snapshot.data()!);
  }

  Future<void> updateCallStatus(
    String callId,
    String status, {
    Map<String, dynamic>? extraData,
  }) {
    return _callsCollection.doc(callId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      ...?extraData,
    }, SetOptions(merge: true));
  }
}
