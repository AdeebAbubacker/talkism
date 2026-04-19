import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      final user = UserModel(
        uid: userCredential.user!.uid,
        name: name,
        email: email,
        role: 'user',
        isOnline: true,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(user.toJson());

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
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .update({
        'isOnline': true,
        'updatedAt': DateTime.now(),
      });

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
        await _firestore.collection('users').doc(currentUserId).update({
          'isOnline': false,
          'updatedAt': DateTime.now(),
        });
      }
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out: $e';
    }
  }

  /// Get user profile from Firestore
  Future<UserModel?> getUserProfile(String uid) async {
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
      await _firestore.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': DateTime.now(),
      });
    } catch (e) {
      throw 'Failed to update user status: $e';
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
