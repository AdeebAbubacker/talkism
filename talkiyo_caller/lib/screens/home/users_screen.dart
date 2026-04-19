import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/agora_service.dart';
import '../../models/user_model.dart';
import '../../models/call_model.dart';
import '../../utils/agora_token_generator.dart';
import '../../components/config_override.dart';
import '../call/outgoing_call_screen.dart';
import '../call/incoming_call_screen.dart';
import '../auth/login_screen.dart';

/// Users list screen showing all registered users
class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _agoraService = AgoraService();
  late String _currentUserId;
  UserModel? _currentUserData;
  StreamSubscription<CallModel?>? _incomingCallSub;
  bool _isShowingIncomingCall = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUserId ?? '';
    _loadCurrentUserData();
    _initializeAgora();
    _listenForIncomingCalls();
  }

  void _listenForIncomingCalls() {
    if (_currentUserId.isEmpty) return;
    _incomingCallSub = _firestoreService
        .streamIncomingCall(_currentUserId)
        .listen((call) {
      if (call != null && mounted && !_isShowingIncomingCall) {
        _isShowingIncomingCall = true;
        Navigator.of(context)
            .push(MaterialPageRoute(
              builder: (_) => IncomingCallScreen(
                call: call,
                agoraService: _agoraService,
                firestoreService: _firestoreService,
              ),
            ))
            .then((_) => _isShowingIncomingCall = false);
      }
    });
  }

  /// Load current user data
  Future<void> _loadCurrentUserData() async {
    try {
      final userData = await _authService.getUserProfile(_currentUserId);
      setState(() => _currentUserData = userData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  /// Initialize Agora service
  Future<void> _initializeAgora() async {
    try {
      await _agoraService.initialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing Agora: $e')),
        );
      }
    }
  }

  /// Start a call to another user
  Future<void> _startCall(UserModel targetUser, bool isVideoCall) async {
    try {
      // Request permissions
      final hasPermission = await _agoraService.requestPermissions(
        requireCamera: isVideoCall,
      );
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Permission denied. Please enable microphone and camera.'),
            ),
          );
        }
        return;
      }

      // Create call document with a per-call channel and dynamically generated token.
      final callId = DateTime.now().millisecondsSinceEpoch.toString();
      final token = AgoraTokenGenerator.generateRtcToken(
        appId: agoraAppId,
        appCertificate: agoraPrimaryCertificate,
        channelName: callId,
      );
      final call = CallModel(
        callId: callId,
        callerId: _currentUserId,
        callerName: _currentUserData?.name ?? 'Unknown',
        callerEmail: _currentUserData?.email ?? 'unknown@email.com',
        receiverId: targetUser.uid,
        receiverName: targetUser.name,
        receiverEmail: targetUser.email,
        channelId: callId,
        token: token,
        callType: isVideoCall ? CallType.video : CallType.audio,
        status: CallStatus.ringing,
        createdAt: DateTime.now(),
      );

      await _firestoreService.createCall(call);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OutgoingCallScreen(
              call: call,
              agoraService: _agoraService,
              firestoreService: _firestoreService,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle logout
  Future<void> _logout() async {
    try {
      await _authService.signOut();
      await _agoraService.dispose();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900,
        title: const Text('Users'),
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Logout'),
                onTap: _logout,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Current user info
          Container(
            color: Colors.blue.shade900,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Text(
                    _currentUserData?.name.isNotEmpty ?? false
                        ? _currentUserData!.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUserData?.name ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currentUserData?.email ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentUserData?.isOnline ?? false)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          // Users list
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream:
                  _firestoreService.streamAllUsersExceptCurrent(_currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No users available',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                final users = snapshot.data!;

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: users.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final user = users[index];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade900,
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.isOnline)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            )
                          else
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: const BoxDecoration(
                                color: Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Audio call button
                          IconButton(
                            icon: const Icon(
                              Icons.call,
                              color: Colors.green,
                            ),
                            onPressed: () => _startCall(user, false),
                          ),
                          // Video call button
                          IconButton(
                            icon: const Icon(
                              Icons.videocam,
                              color: Colors.blue,
                            ),
                            onPressed: () => _startCall(user, true),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    _agoraService.dispose();
    super.dispose();
  }
}
