import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
          .map((doc) =>
              UserModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
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
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                UserModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
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
      await _firestore.collection('calls').doc(callId).update({
        'status': _callStatusToString(status),
        if (status == CallStatus.accepted)
          'acceptedAt': DateTime.now()
        else if (status == CallStatus.ended)
          'endedAt': DateTime.now(),
      });
    } catch (e) {
      throw 'Failed to update call status: $e';
    }
  }

  /// Get call by ID
  Future<CallModel?> getCallById(String callId) async {
    try {
      final doc = await _firestore.collection('calls').doc(callId).get();
      if (doc.exists) {
        return CallModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
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
          snapshot.docs.first.id);
    });
  }

  /// Stream call status changes
  Stream<CallModel?> streamCallStatus(String callId) {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return CallModel.fromJson(snapshot.data()!, snapshot.id);
    });
  }

  /// Get recent calls for a user
  Future<List<CallModel>> getRecentCalls(String userId,
      {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('calls')
          .where('callerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) =>
              CallModel.fromJson(doc.data(), doc.id))
          .toList();
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
}
