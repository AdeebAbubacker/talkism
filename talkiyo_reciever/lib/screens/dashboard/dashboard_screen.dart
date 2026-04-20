import 'package:flutter/material.dart';
import 'package:talkiyo_reciever/screens/dashboard/sections/call_section.dart';
import 'package:talkiyo_reciever/screens/dashboard/sections/coin_section.dart';
import 'package:talkiyo_reciever/screens/dashboard/sections/profile_section.dart';
import 'package:talkiyo_reciever/screens/dashboard/sections/wallet_section.dart';
import 'package:talkiyo_reciever/screens/notification/notification_screen.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/agora_service.dart';
import '../../services/notification_service.dart';
import '../../models/user_model.dart';
import '../../models/call_model.dart';
import '../call/incoming_call_screen.dart';

class UsedddddrsScreen extends StatefulWidget {
  const UsedddddrsScreen({super.key});

  @override
  State<UsedddddrsScreen> createState() => _UsedddddrsScreenState();
}

class _UsedddddrsScreenState extends State<UsedddddrsScreen>
    with WidgetsBindingObserver {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _agoraService = AgoraService();

  late String _currentUserId;
  UserModel? _currentUserData;
  StreamSubscription<CallModel?>? _incomingCallSub;
  StreamSubscription<String>? _notificationTapSub;
  Timer? _presenceTimer;

  bool _isShowingIncomingCall = false;
  int selectedIndex = 0;

  final List<String> pageTitles = const [
    "Home",
    "Calls",
    "Earnings",
    "Wallet",
    "Profile",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUserId = _authService.currentUserId ?? '';
    _loadCurrentUserData();
    _initializeAgora();
    _listenForIncomingCalls();
    _initializeNotifications();
    _startPresenceHeartbeat();
  }

  void _startPresenceHeartbeat() {
    if (_currentUserId.isEmpty) return;

    _presenceTimer?.cancel();
    unawaited(_setCurrentUserPresence(true));
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_setCurrentUserPresence(true, updateLocal: false));
      if (mounted) setState(() {});
    });
  }

  Future<void> _setCurrentUserPresence(
    bool isOnline, {
    bool updateLocal = true,
  }) async {
    if (_currentUserId.isEmpty) return;

    try {
      await _authService.updateUserStatus(
        uid: _currentUserId,
        isOnline: isOnline,
      );
    } catch (e) {
      debugPrint('Failed to update presence: $e');
    }

    if (!updateLocal || !mounted) return;

    final currentUserData = _currentUserData;
    if (currentUserData == null) return;

    setState(() {
      _currentUserData = currentUserData.copyWith(
        isOnline: isOnline,
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPresenceHeartbeat();
      return;
    }

    _presenceTimer?.cancel();
    unawaited(_setCurrentUserPresence(false, updateLocal: false));
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

  Widget _buildReceiverHome() {
    final displayName = _currentUserData?.name.trim();

    return StreamBuilder<CallModel?>(
      stream: _currentUserId.isEmpty
          ? const Stream<CallModel?>.empty()
          : _firestoreService.streamIncomingCall(_currentUserId),
      builder: (context, snapshot) {
        final incomingCall = snapshot.data;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
          children: [
            Text(
              displayName == null || displayName.isEmpty
                  ? 'Ready to receive calls'
                  : 'Hi, $displayName',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Stay online, answer calls, and track your earnings.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            _AvailabilityCard(isOnline: _currentUserData?.isOnlineNow ?? false),
            const SizedBox(height: 16),
            if (incomingCall == null)
              const _NoIncomingCallCard()
            else
              _IncomingCallCard(
                call: incomingCall,
                onPickUp: () =>
                    _openIncomingCallFromNotification(incomingCall.callId),
              ),
            const SizedBox(height: 16),
            const _ReceiverEarningInfoCard(),
          ],
        );
      },
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
      return _buildReceiverHome();
    } else if (selectedIndex == 1) {
      return CallSection(
        currentUserId: _currentUserId,
        firestoreService: _firestoreService,
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
            _navItem(index: 1, icon: Icons.call_outlined, label: 'Calls'),
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
    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();
    unawaited(_setCurrentUserPresence(false, updateLocal: false));
    _incomingCallSub?.cancel();
    _notificationTapSub?.cancel();
    _agoraService.dispose();
    super.dispose();
  }
}

class _AvailabilityCard extends StatelessWidget {
  final bool isOnline;

  const _AvailabilityCard({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFFE7F8ED)
                  : const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isOnline ? Icons.wifi_tethering_rounded : Icons.cloud_off,
              color: isOnline ? const Color(0xFF19A463) : Colors.grey,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Available for Calls' : 'Offline',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isOnline
                      ? 'Incoming calls will appear here instantly.'
                      : 'Sign in again to appear online for callers.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoIncomingCallCard extends StatelessWidget {
  const _NoIncomingCallCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EAFF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.call_received_rounded,
                  color: Color(0xFF7E3DFF),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'No incoming calls right now',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'When a user calls you, the incoming screen and notification will show with accept and reject controls.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingCallCard extends StatelessWidget {
  final CallModel call;
  final VoidCallback onPickUp;

  const _IncomingCallCard({required this.call, required this.onPickUp});

  @override
  Widget build(BuildContext context) {
    final callIcon = call.callType == CallType.video
        ? Icons.videocam_rounded
        : Icons.call_rounded;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF22B61E), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F8ED),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(callIcon, color: const Color(0xFF19A463), size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Incoming Call',
                  style: TextStyle(
                    color: Color(0xFF19A463),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  call.callerName.trim().isEmpty
                      ? 'Unknown User'
                      : call.callerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  call.callType == CallType.video ? 'Video call' : 'Audio call',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onPickUp,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF22B61E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiverEarningInfoCard extends StatelessWidget {
  const _ReceiverEarningInfoCard();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _ReceiverMetricCard(
            icon: Icons.monetization_on,
            label: 'Rate',
            value: '2/sec',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _ReceiverMetricCard(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Wallet',
            value: 'Earnings',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _ReceiverMetricCard(
            icon: Icons.verified_user_outlined,
            label: 'Role',
            value: 'Receiver',
          ),
        ),
      ],
    );
  }
}

class _ReceiverMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReceiverMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF7E3DFF), size: 24),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
