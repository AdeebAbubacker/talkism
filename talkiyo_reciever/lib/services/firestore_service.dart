import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/call_model.dart';

/// Service for handling Firestore operations
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch all users except the current user
  Future<List<UserModel>> getAllUsersExceptCurrent(String currentUserId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('uid', isNotEqualTo: currentUserId)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Failed to fetch users: $e';
    }
  }

  /// Stream all users except current user (real-time updates)
  Stream<List<UserModel>> streamAllUsersExceptCurrent(String currentUserId) {
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Create a new call document in Firestore
  Future<String> createCall(CallModel call) async {
    try {
      await _firestore.collection('calls').doc(call.callId).set(call.toJson());
      return call.callId;
    } catch (e) {
      throw 'Failed to create call: $e';
    }
  }

  /// Update call status
  Future<void> updateCallStatus(String callId, CallStatus status) async {
    try {
      final callRef = _firestore.collection('calls').doc(callId);
      final now = DateTime.now();
      final updates = <String, dynamic>{'status': _callStatusToString(status)};

      if (status == CallStatus.accepted) {
        updates['acceptedAt'] = now;
      } else if (status == CallStatus.ended) {
        updates['endedAt'] = now;

        final callSnapshot = await callRef.get();
        final data = callSnapshot.data();
        final acceptedAt = _dateTimeFromValue(data?['acceptedAt']);

        if (acceptedAt != null) {
          final duration = now.difference(acceptedAt).inSeconds;
          updates['durationInSeconds'] = duration < 0 ? 0 : duration;
        }
      }

      await callRef.update(updates);
    } catch (e) {
      throw 'Failed to update call status: $e';
    }
  }

  /// Get call by ID
  Future<CallModel?> getCallById(String callId) async {
    try {
      final doc = await _firestore.collection('calls').doc(callId).get();
      if (doc.exists) {
        return CallModel.fromJson(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw 'Failed to get call: $e';
    }
  }

  /// Stream incoming call requests (for specific receiver)
  Stream<CallModel?> streamIncomingCall(String receiverId) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'ringing')
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return CallModel.fromJson(
            snapshot.docs.first.data(),
            snapshot.docs.first.id,
          );
        });
  }

  /// Stream call status changes
  Stream<CallModel?> streamCallStatus(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return null;
      return CallModel.fromJson(snapshot.data()!, snapshot.id);
    });
  }

  /// Stream recent calls for a user as caller or receiver.
  Stream<List<CallModel>> streamRecentCalls(String userId, {int limit = 40}) {
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    outgoingSub;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    incomingSub;

    final controller = StreamController<List<CallModel>>.broadcast();

    List<CallModel> outgoingCalls = [];
    List<CallModel> incomingCalls = [];

    void emitMergedCalls() {
      if (controller.isClosed) return;

      final merged = _mergeAndSortCalls([
        ...outgoingCalls,
        ...incomingCalls,
      ], limit: limit);

      controller.add(merged);
    }

    void handleError(Object error, StackTrace stackTrace) {
      if (!controller.isClosed) {
        controller.addError(error, stackTrace);
      }
    }

    outgoingSub = _firestore
        .collection('calls')
        .where('callerId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
          outgoingCalls = _callsFromSnapshot(snapshot);
          emitMergedCalls();
        }, onError: handleError);

    incomingSub = _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
          incomingCalls = _callsFromSnapshot(snapshot);
          emitMergedCalls();
        }, onError: handleError);

    controller.onCancel = () async {
      await outgoingSub.cancel();
      await incomingSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Get recent calls for a user
  Future<List<CallModel>> getRecentCalls(
    String userId, {
    int limit = 20,
  }) async {
    try {
      final results = await Future.wait([
        _firestore
            .collection('calls')
            .where('callerId', isEqualTo: userId)
            .get(),
        _firestore
            .collection('calls')
            .where('receiverId', isEqualTo: userId)
            .get(),
      ]);

      final outgoingSnapshot = results[0];
      final incomingSnapshot = results[1];

      return _mergeAndSortCalls([
        ..._callsFromSnapshot(outgoingSnapshot),
        ..._callsFromSnapshot(incomingSnapshot),
      ], limit: limit);
    } catch (e) {
      throw 'Failed to fetch recent calls: $e';
    }
  }

  /// Delete a call document
  Future<void> deleteCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).delete();
    } catch (e) {
      throw 'Failed to delete call: $e';
    }
  }

  /// Helper to convert CallStatus enum to string
  String _callStatusToString(CallStatus status) {
    return status.toString().split('.').last;
  }

  List<CallModel> _callsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => CallModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  List<CallModel> _mergeAndSortCalls(
    List<CallModel> calls, {
    required int limit,
  }) {
    final uniqueCalls = <String, CallModel>{};

    for (final call in calls) {
      uniqueCalls[call.callId] = call;
    }

    final sortedCalls = uniqueCalls.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sortedCalls.take(limit).toList();
  }

  DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
