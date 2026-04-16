import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/call_controller.dart';
import '../../core/services/default_dialer_service.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/users_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/calling/outgoing_call_screen.dart';
import '../../widgets/user_tile.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const UserListScreen());
  }

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen>
    with WidgetsBindingObserver {
  bool _isDefaultDialer = false;
  bool _isCheckingDialerRole = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDefaultDialerStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDefaultDialerStatus();
    }
  }

  Future<void> _startCall(
    BuildContext context,
    AppUser caller,
    AppUser receiver,
  ) async {
    final callController = context.read<CallController>();
    final started = await callController.startOutgoingCall(
      caller: caller,
      receiver: receiver,
    );

    if (!context.mounted) {
      return;
    }

    if (!started) {
      final message = callController.errorMessage ?? 'Unable to start call.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      callController.clearMessages();
      return;
    }

    await Navigator.of(context).push(OutgoingCallScreen.route());
    if (!context.mounted) {
      return;
    }

    await callController.reset();
  }

  Future<void> _refreshDefaultDialerStatus() async {
    if (!DefaultDialerService.isSupported || !mounted) {
      return;
    }

    setState(() {
      _isCheckingDialerRole = true;
    });

    final isDefaultDialer = await DefaultDialerService.isDefaultDialer();
    if (!mounted) {
      return;
    }

    setState(() {
      _isDefaultDialer = isDefaultDialer;
      _isCheckingDialerRole = false;
    });
  }

  Future<void> _requestDefaultDialer() async {
    final launched = await DefaultDialerService.requestDefaultDialer();
    if (!mounted) {
      return;
    }

    if (!launched) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to open the default dialer request screen.'),
          ),
        );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushAndRemoveUntil(LoginScreen.route(), (route) => false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final usersProvider = context.watch<UsersProvider>();
    final caller = authProvider.appUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Talkiyo Dialer'),
        actions: [
          IconButton(
            onPressed: authProvider.isLoading ? null : () => _logout(context),
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signed in as',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      caller?.displayName ??
                          authProvider.firebaseUser?.email ??
                          'Talkiyo User',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Call any online Talkiyo user with Agora voice. Incoming calls will ring inside this app too.',
                      style: TextStyle(color: Colors.white70, height: 1.45),
                    ),
                  ],
                ),
              ),
              if (DefaultDialerService.isSupported) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: _isDefaultDialer
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _isDefaultDialer
                              ? Icons.check_circle
                              : Icons.dialpad_rounded,
                          color: _isDefaultDialer
                              ? const Color(0xFF15803D)
                              : const Color(0xFF1D4ED8),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isDefaultDialer
                                  ? 'Talkiyo is your default dialer'
                                  : 'Set Talkiyo as default dialer',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isDefaultDialer
                                  ? 'Android will prefer Talkiyo for dial actions on this device.'
                                  : 'Use Android system settings to make Talkiyo the phone app opened for dial intents.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: _isDefaultDialer || _isCheckingDialerRole
                            ? null
                            : _requestDefaultDialer,
                        child: Text(
                          _isCheckingDialerRole ? 'Checking...' : 'Enable',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (usersProvider.isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (usersProvider.errorMessage != null)
                Expanded(
                  child: Center(child: Text(usersProvider.errorMessage!)),
                )
              else if (usersProvider.receivers.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No other Talkiyo users found in Firestore yet.',
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: usersProvider.receivers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final receiver = usersProvider.receivers[index];
                      return UserTile(
                        user: receiver,
                        onCallTap: caller == null
                            ? null
                            : () => _startCall(context, caller, receiver),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
