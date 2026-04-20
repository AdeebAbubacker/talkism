import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:talkiyo_caller/screens/dashboard/sections/call_section.dart';
import 'package:talkiyo_caller/screens/dashboard/sections/coin_section.dart';
import 'package:talkiyo_caller/screens/dashboard/sections/profile_section.dart';
import 'package:talkiyo_caller/screens/dashboard/sections/wallet_section.dart';
import 'package:talkiyo_caller/screens/notification/notification_screen.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/agora_service.dart';
import '../../services/notification_service.dart';
import '../../models/user_model.dart';
import '../../models/call_model.dart';
import '../../utils/agora_token_generator.dart';
import '../../components/config_override.dart';
import '../call/outgoing_call_screen.dart';
import '../call/incoming_call_screen.dart';

class UsedddddrsScreen extends StatefulWidget {
  const UsedddddrsScreen({super.key});

  @override
  State<UsedddddrsScreen> createState() => _UsedddddrsScreenState();
}

class _UsedddddrsScreenState extends State<UsedddddrsScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _agoraService = AgoraService();

  late String _currentUserId;
  UserModel? _currentUserData;
  StreamSubscription<CallModel?>? _incomingCallSub;
  StreamSubscription<String>? _notificationTapSub;

  bool _isShowingIncomingCall = false;
  int selectedIndex = 0;

  final List<String> pageTitles = const [
    "Home",
    "My Calls",
    "Add Coin",
    "Wallet",
    "Profile",
  ];

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUserId ?? '';
    _loadCurrentUserData();
    _initializeAgora();
    _listenForIncomingCalls();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await NotificationService.syncTokenForCurrentUser();
    if (!mounted) return;

    _notificationTapSub = NotificationService.callTapStream.listen(
      _openIncomingCallFromNotification,
    );

    final pendingCallId = NotificationService.takePendingCallId();
    if (pendingCallId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openIncomingCallFromNotification(pendingCallId);
      });
    }
  }

  void _listenForIncomingCalls() {
    if (_currentUserId.isEmpty) return;

    _incomingCallSub = _firestoreService
        .streamIncomingCall(_currentUserId)
        .listen((call) {
          if (call != null && mounted && !_isShowingIncomingCall) {
            unawaited(
              NotificationService.showIncomingCallNotificationForCall(call),
            );
            _isShowingIncomingCall = true;
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => IncomingCallScreen(
                      call: call,
                      agoraService: _agoraService,
                      firestoreService: _firestoreService,
                    ),
                  ),
                )
                .then((_) => _isShowingIncomingCall = false);
          }
        });
  }

  Future<void> _openIncomingCallFromNotification(String callId) async {
    if (!mounted || _isShowingIncomingCall || _currentUserId.isEmpty) return;

    try {
      final call = await _firestoreService.getCallById(callId);
      if (!mounted || call == null) return;
      if (call.status != CallStatus.ringing ||
          call.receiverId != _currentUserId) {
        return;
      }

      if (!mounted) return;

      _isShowingIncomingCall = true;
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => IncomingCallScreen(
                call: call,
                agoraService: _agoraService,
                firestoreService: _firestoreService,
              ),
            ),
          )
          .then((_) => _isShowingIncomingCall = false);
    } catch (e) {
      debugPrint('Failed to open incoming call from notification: $e');
    }
  }

  Future<void> _loadCurrentUserData() async {
    try {
      final userData = await _authService.getUserProfile(_currentUserId);
      if (mounted) {
        setState(() => _currentUserData = userData);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  Future<void> _initializeAgora() async {
    try {
      await _agoraService.initialize();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error initializing Agora: $e')));
    }
  }

  Future<void> _startCall(UserModel targetUser, bool isVideoCall) async {
    try {
      final hasPermission = await _agoraService.requestPermissions(
        requireCamera: isVideoCall,
      );

      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permission denied. Please enable microphone and camera.',
            ),
          ),
        );
        return;
      }

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

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OutgoingCallScreen(
            call: call,
            agoraService: _agoraService,
            firestoreService: _firestoreService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startCallFromHistory(CallModel call, bool isVideoCall) async {
    final isOutgoing = call.callerId == _currentUserId;
    final now = DateTime.now();
    final targetUser = UserModel(
      uid: isOutgoing ? call.receiverId : call.callerId,
      name: isOutgoing ? call.receiverName : call.callerName,
      email: isOutgoing ? call.receiverEmail : call.callerEmail,
      isOnline: false,
      updatedAt: now,
      createdAt: now,
    );

    await _startCall(targetUser, isVideoCall);
  }

  void onTabTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  Widget _buildTopSection() {
    return Container(
      height: 180,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF651FFF), Color(0xFFB14DFF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Talkiyo',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  _topIconBox(
                    width: 104,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.monetization_on,
                          color: Colors.amber,
                          size: 28,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '0',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topIconBox({required Widget child, required double width}) {
    return Container(
      width: width,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }

  Widget _buildHomeUsers() {
    return StreamBuilder<List<UserModel>>(
      stream: _firestoreService.streamAllUsersExceptCurrent(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No users available',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          );
        }

        final users = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "Listeners",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.tune, color: Colors.grey, size: 24),
                    SizedBox(width: 8),
                    Text(
                      "മലയാളം",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...users.map((user) => _listenerCard(user)),
          ],
        );
      },
    );
  }

  Widget _listenerCard(UserModel user) {
    // final imageUrl = (user.imageUrl != null && user.imageUrl!.trim().isNotEmpty)
    //     ? user.imageUrl!.trim()
    //     : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 92,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFD8B4F8),
                  image:
                      (user.profilePic != null && user.profilePic!.isNotEmpty)
                      ? DecorationImage(
                          image: MemoryImage(base64Decode(user.profilePic!)),
                          fit: BoxFit.cover, // fills the container
                        )
                      : null,
                ),
                child: (user.profilePic == null || user.profilePic!.isEmpty)
                    ? const Center(
                        child: Icon(Icons.person, color: Colors.grey, size: 36),
                      )
                    : null,
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: user.isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name.isNotEmpty ? user.name : 'Unknown User',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'User',
                        style: TextStyle(fontSize: 17, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 18, color: Colors.grey[300]),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.monetization_on,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.isOnline ? '2/Sec' : 'Offline',
                        style: TextStyle(
                          fontSize: 16,
                          color: user.isOnline
                              ? const Color(0xFFDA9E16)
                              : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        color: Colors.grey,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              InkWell(
                onTap: () => _startCall(user, false),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22B61E),
                    borderRadius: BorderRadius.circular(45),
                  ),
                  child: const Icon(Icons.call, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _startCall(user, true),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3478F6),
                    borderRadius: BorderRadius.circular(45),
                  ),
                  child: const Icon(
                    Icons.videocam,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPage(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 130),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$title Placeholder',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (selectedIndex == 0) {
      return _buildHomeUsers();
    } else if (selectedIndex == 1) {
      return CallSection(
        currentUserId: _currentUserId,
        firestoreService: _firestoreService,
        onStartCall: _startCallFromHistory,
      );
    } else if (selectedIndex == 2) {
      return CoinSection();
    } else if (selectedIndex == 3) {
      return WalletScreen();
    } else if (selectedIndex == 4) {
      return ProfileSection();
    }
    return _buildPlaceholderPage(pageTitles[selectedIndex]);
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 250),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF8E4DFF) : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF8E4DFF) : Colors.grey,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 45,
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(index: 0, icon: Icons.home_outlined, label: 'Home'),
            _navItem(index: 1, icon: Icons.call_outlined, label: 'My Calls'),
            GestureDetector(
              onTap: () => onTabTapped(2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: selectedIndex == 2 ? 68 : 60,
                height: selectedIndex == 2 ? 68 : 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C1FFF), Color(0xFFB14DFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.monetization_on,
                  color: Colors.amber,
                  size: 34,
                ),
              ),
            ),
            _navItem(
              index: 3,
              icon: Icons.account_balance_wallet_outlined,
              label: 'Wallet',
            ),
            _navItem(index: 4, icon: Icons.person_outline, label: 'Profile'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: selectedIndex == 2
          ? Colors.white
          : const Color(0xFFF3F3F3),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopSection(),
              Expanded(child: _buildBody()),
            ],
          ),
          _buildFloatingNavBar(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    _notificationTapSub?.cancel();
    _agoraService.dispose();
    super.dispose();
  }
}
