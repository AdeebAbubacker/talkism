import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talkiyo_reciever/services/auth_service.dart';

class ProfileSection extends StatefulWidget {
  const ProfileSection({super.key});

  @override
  State<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<ProfileSection> {
  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      setState(() {
        profileImageUrl = doc.data()?['profilePic'] as String?;
      });
    } catch (e) {
      debugPrint('Failed to load profile image: $e');
    }
  }

  String? profileImageUrl;
  bool isUploading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _onAddPhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 40,
        maxWidth: 300,
        maxHeight: 300,
      );

      if (pickedFile == null) return;

      setState(() {
        isUploading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();

      // Validate size (Firestore document limit)
      final sizeKB = bytes.lengthInBytes / 1024;

      if (sizeKB > 300) {
        throw Exception('Image must be under 300KB');
      }

      final base64Image = base64Encode(bytes);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'profilePic': base64Image, 'updatedAt': DateTime.now()},
      );

      setState(() {
        profileImageUrl = base64Image;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  /// Logout
  Future<void> _logout() async {
    try {
      await AuthService().signOut();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return const _InfoSheet(
          title: 'Privacy Policy',
          content:
              'Your privacy is important to us.\n\n'
              'This app may collect basic account information such as name, email, '
              'and profile picture to provide the service.\n\n'
              'We do not share your personal data with third parties except where '
              'required for app functionality or by law.\n\n'
              'By using this app, you agree to this privacy policy.',
        );
      },
    );
  }

  void _showTermsAndConditions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return const _InfoSheet(
          title: 'Terms & Conditions',
          content:
              'By using this app, you agree to use it responsibly and lawfully.\n\n'
              'Users are responsible for the content they share and their account activity.\n\n'
              'We reserve the right to modify or discontinue the service at any time.\n\n'
              'Continued use of the app means you accept these terms.',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      profileImageUrl != null && profileImageUrl!.isNotEmpty
                      ? MemoryImage(base64Decode(profileImageUrl!))
                      : null,
                  child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: isUploading ? null : _onAddPhoto,
                  icon: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  label: Text(isUploading ? 'Uploading...' : 'Add Photo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showPrivacyPolicy,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms & Conditions'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showTermsAndConditions,
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('App Version'),
                  subtitle: Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoSheet extends StatelessWidget {
  final String title;
  final String content;

  const _InfoSheet({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    content,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
