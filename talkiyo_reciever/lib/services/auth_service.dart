import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Service for handling Firebase Authentication
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user UID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get current user from Firebase
  User? get currentUser => _auth.currentUser;

  /// Stream to listen to authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Register a new user with email and password
  Future<UserCredential?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Create user account
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Create user document in Firestore
      final user = UserModel(
        uid: userCredential.user!.uid,
        name: name,
        email: email,
        role: 'receiver',
        isOnline: true,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _runBestEffortFirestoreWrite(
        () => _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(user.toJson(), SetOptions(merge: true)),
        context: 'create user profile',
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user status to online
      await _runBestEffortFirestoreWrite(
        () => _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          if (userCredential.user!.email != null)
            'email': userCredential.user!.email,
          if (userCredential.user!.displayName != null)
            'name': userCredential.user!.displayName,
          'role': 'receiver',
          'isOnline': true,
          'updatedAt': DateTime.now(),
        }, SetOptions(merge: true)),
        context: 'mark user online',
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      // Update user status to offline
      if (currentUserId != null) {
        await _runBestEffortFirestoreWrite(
          () => _firestore.collection('users').doc(currentUserId).set({
            'isOnline': false,
            'lastSeen': DateTime.now(),
            'updatedAt': DateTime.now(),
          }, SetOptions(merge: true)),
          context: 'mark user offline',
        );
      }
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out: $e';
    }
  }

  /// Get user profile from Firestore
  Future<UserModel?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      throw 'Failed to get user profile: $e';
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Update user online status
  Future<void> updateUserStatus({
    required String uid,
    required bool isOnline,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'isOnline': isOnline,
        'lastSeen': DateTime.now(),
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw 'Failed to update user status: $e';
    }
  }

  /// Update profile picture URL in users collection
  Future<void> updateProfilePictureBase64(File imageFile) async {
    try {
      final uid = currentUserId;

      if (uid == null) {
        throw 'User not logged in';
      }

      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Convert to base64
      final base64Image = base64Encode(bytes);

      // Validate size (Firestore document limit ~1MB)
      final sizeKB = bytes.lengthInBytes / 1024;

      if (sizeKB > 300) {
        throw 'Image too large. Please choose an image under 300KB.';
      }

      await _firestore.collection('users').doc(uid).set({
        'profilePic': base64Image,
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw 'Failed to update profile picture: $e';
    }
  }

  /// Optional: remove profile picture
  Future<void> removeProfilePicture() async {
    try {
      final uid = currentUserId;

      if (uid == null) {
        throw 'User not logged in';
      }

      await _firestore.collection('users').doc(uid).set({
        'profilePic': null,
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw 'Failed to remove profile picture: $e';
    }
  }

  Future<void> _runBestEffortFirestoreWrite(
    Future<void> Function() write, {
    required String context,
  }) async {
    try {
      await write();
    } catch (e) {
      debugPrint('Auth succeeded, but failed to $context: $e');
    }
  }

  /// Handle Firebase Authentication exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'operation-not-allowed':
        return 'Operation not allowed.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
