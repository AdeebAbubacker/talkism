import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? profileImage;
  final String? fcmToken;
  final String? role;
  final bool isOnline;
  final DateTime updatedAt;
  final DateTime createdAt;
  final String? profilePic;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.profileImage,
    this.fcmToken,
    this.role,
    required this.isOnline,
    required this.updatedAt,
    required this.createdAt,
    this.profilePic,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profileImage: json['profileImage'],
      fcmToken: json['fcmToken'],
      role: json['role'],
      isOnline: json['isOnline'] ?? false,
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profilePic: json['profilePic'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      if (profileImage != null) 'profileImage': profileImage,
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (role != null) 'role': role,
      'isOnline': isOnline,
      'updatedAt': updatedAt,
      'createdAt': createdAt,
      'profilePic': profilePic,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? profileImage,
    String? fcmToken,
    String? role,
    bool? isOnline,
    DateTime? updatedAt,
    DateTime? createdAt,
    String? profilePic,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      fcmToken: fcmToken ?? this.fcmToken,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      profilePic: profilePic ?? this.profilePic,
    );
  }
}
