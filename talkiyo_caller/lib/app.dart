import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/call_controller.dart';
import 'core/services/agora_service.dart';
import 'core/services/agora_token_service.dart';
import 'core/services/call_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/installation_service.dart';
import 'core/services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/users_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/calling/incoming_call_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/users/user_list_screen.dart';

class CallerApp extends StatefulWidget {
  const CallerApp({
    super.key,
    required this.notificationService,
    required this.installationService,
  });

  final NotificationService notificationService;
  final InstallationService installationService;

  @override
  State<CallerApp> createState() => _CallerAppState();
}

class _CallerAppState extends State<CallerApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService.instance;
    final callService = CallService(
      firestoreService: firestoreService,
      agoraService: AgoraService(),
      agoraTokenService: const AgoraTokenService(),
    );

    return MultiProvider(
      providers: [
        Provider<FirebaseAuth>.value(value: FirebaseAuth.instance),
        Provider<FirebaseApp>.value(value: Firebase.app()),
        Provider<FirestoreService>.value(value: firestoreService),
        Provider<NotificationService>.value(value: widget.notificationService),
        Provider<InstallationService>.value(value: widget.installationService),
        Provider<CallService>.value(value: callService),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            firebaseAuth: FirebaseAuth.instance,
            firestoreService: firestoreService,
            notificationService: widget.notificationService,
          )..initialize(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, UsersProvider>(
          create: (_) => UsersProvider(firestoreService: firestoreService),
          update: (_, authProvider, usersProvider) {
            final provider =
                usersProvider ??
                UsersProvider(firestoreService: firestoreService);
            provider.bindCurrentUser(authProvider.appUser?.uid);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, CallController>(
          create: (_) => CallController(
            callService: callService,
            notificationService: widget.notificationService,
            installationService: widget.installationService,
          ),
          update: (_, authProvider, callController) {
            final controller =
                callController ??
                CallController(
                  callService: callService,
                  notificationService: widget.notificationService,
                  installationService: widget.installationService,
                );
            controller.bindCurrentUser(authProvider.appUser);
            return controller;
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Talkiyo Caller',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F9D7A),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F7F5),
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF0F9D7A),
                width: 1.4,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
          ),
        ),
        builder: (context, child) => _CallFlowCoordinator(
          navigatorKey: _navigatorKey,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const _AppEntry(),
      ),
    );
  }
}

class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isInitializing) {
          return const SplashScreen();
        }

        if (authProvider.isAuthenticated) {
          return const UserListScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class _CallFlowCoordinator extends StatefulWidget {
  const _CallFlowCoordinator({required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<_CallFlowCoordinator> createState() => _CallFlowCoordinatorState();
}

class _CallFlowCoordinatorState extends State<_CallFlowCoordinator> {
  bool _isPresentingIncomingCall = false;
  String? _presentedIncomingCallId;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthProvider, bool>(
      (authProvider) => authProvider.isAuthenticated,
    );
    final callController = context.watch<CallController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _syncIncomingCallPresentation(
          isAuthenticated: isAuthenticated,
          callController: callController,
        ),
      );
    });

    return widget.child;
  }

  Future<void> _syncIncomingCallPresentation({
    required bool isAuthenticated,
    required CallController callController,
  }) async {
    if (!mounted || !isAuthenticated || !callController.hasIncomingCall) {
      return;
    }

    final callId = callController.currentCall?.callId;
    if (_isPresentingIncomingCall && _presentedIncomingCallId == callId) {
      return;
    }

    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    _isPresentingIncomingCall = true;
    _presentedIncomingCallId = callId;

    await navigator.push(IncomingCallScreen.route());

    if (!mounted) {
      return;
    }

    _isPresentingIncomingCall = false;
    _presentedIncomingCallId = null;
  }
}
