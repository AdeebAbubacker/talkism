import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/agora_service.dart';
import 'core/services/agora_token_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/receiver_user_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/call/call_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/incoming_call/incoming_call_screen.dart';
import 'screens/splash/splash_screen.dart';

class ReceiverApp extends StatelessWidget {
  const ReceiverApp({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<AgoraService>(create: (_) => AgoraService()),
        Provider<AgoraTokenService>(create: (_) => const AgoraTokenService()),
        Provider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) =>
              AuthProvider(authService: context.read<AuthService>())
                ..initialize(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ReceiverUserProvider>(
          create: (context) => ReceiverUserProvider(
            firestoreService: context.read<FirestoreService>(),
            notificationService: context.read<NotificationService>(),
          )..initialize(),
          update: (_, authProvider, receiverUserProvider) {
            receiverUserProvider?.attachAuthUser(authProvider.user);
            return receiverUserProvider!;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, CallProvider>(
          create: (context) => CallProvider(
            firestoreService: context.read<FirestoreService>(),
            agoraService: context.read<AgoraService>(),
            agoraTokenService: context.read<AgoraTokenService>(),
            notificationService: context.read<NotificationService>(),
          )..initialize(),
          update: (_, authProvider, callProvider) {
            callProvider?.attachAuthUser(authProvider.user);
            return callProvider!;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Talkiyo Receiver',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F766E),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF3F7F8),
          useMaterial3: true,
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
          ),
        ),
        home: const AppGate(),
      ),
    );
  }
}

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CallProvider>(
      builder: (context, authProvider, callProvider, _) {
        if (!authProvider.isInitialized) {
          return const SplashScreen();
        }

        if (authProvider.user == null) {
          return const LoginScreen();
        }

        switch (callProvider.callState) {
          case CallUiState.incoming:
            return const IncomingCallScreen();
          case CallUiState.active:
            return const CallScreen();
          case CallUiState.idle:
          case CallUiState.ended:
            return const HomeScreen();
        }
      },
    );
  }
}
