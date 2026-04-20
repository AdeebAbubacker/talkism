import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:talkiyo_reciever/screens/auth/splash_screen.dart';
import 'package:talkiyo_reciever/screens/dashboard/dashboard_screen.dart';
import 'package:talkiyo_reciever/services/notification_service.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleDeviceCheckProvider(),
  );
  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agora Calling',
      navigatorKey: NotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        textTheme: GoogleFonts.montserratTextTheme(),
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const UsedddddrsScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
