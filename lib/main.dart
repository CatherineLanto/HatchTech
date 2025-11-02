// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_wrapper.dart';
import 'services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification service to show a notification
  await FcmLocalNotificationService.instance.init();
  await FcmLocalNotificationService.instance.showNotificationFromRemoteMessage(message);
  print('Handling a background message: ${message.messageId}');
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // NOTE: initialize the local notification plugin from the app isolate
  // (we do this in the app widget's initState below) to avoid MissingPlugin
  // exceptions that can happen if plugins aren't registered yet.

  // Request notification permissions (iOS, Android 13+)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Get the device token for sending targeted notifications
  final fcmToken = await FirebaseMessaging.instance.getToken();
  print('FCM Token: $fcmToken');

  // Save FCM token to Firestore for current user (if signed in)
  // This requires AuthService.currentUser and FirebaseFirestore
  try {
    final user = AuthService.currentUser;
    if (user != null && fcmToken != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'fcmToken': fcmToken});
    }
  } catch (e) {
    print('Error saving FCM token: $e');
  }

  runApp(const HatchTechApp());
}

class HatchTechApp extends StatefulWidget {
  const HatchTechApp({super.key});

  @override
  State<HatchTechApp> createState() => _HatchTechAppState();
}

class _HatchTechAppState extends State<HatchTechApp> {
  @override
  void initState() {
    super.initState();

    // Initialize local notifications and set up message listeners here.
    // Wrap initialize in try/catch so a MissingPluginException doesn't crash the app.
    FcmLocalNotificationService.instance.init().catchError((err) {
      // MissingPluginException often means the app was hot-reloaded without a
      // full restart. Recommend full restart if this occurs.
      print('Local notification init error: $err');
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📩 Foreground FCM received: ${message.data}');

    final data = message.data;
    final type = data['type'] ?? 'general';
    final title = data['title'] ?? message.notification?.title ?? 'HatchTech Alert';
    final body = data['body'] ?? message.notification?.body ?? 'Check incubator status.';

    FcmLocalNotificationService.instance.showNotification(
      title: title,
      body: body,
      type: type,
    );
  });

    // When the app is opened from a terminated state via a notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        // handle navigation based on message.data if needed
        print('App opened from terminated state by notification: ${message.messageId}');
      }
    });

    // When app is in background and opened by tapping notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification caused app to open: ${message.messageId}');
      // handle navigation
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'HatchTech',
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.light),
            textTheme: GoogleFonts.poppinsTextTheme(),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueAccent, 
              brightness: Brightness.dark,
            ).copyWith(
              surface: const Color(0xFF121212), 
              onSurface: Colors.white, 
              surfaceContainerHighest: const Color(0xFF1E1E1E), 
              onSurfaceVariant: const Color(0xFFE1E1E1), 
              primary: const Color(0xFF6BB6FF), 
              onPrimary: Colors.black, 
              secondary: const Color(0xFF03DAC6), 
              onSecondary: Colors.black,
              error: const Color(0xFFCF6679), 
              onError: Colors.black,
              outline: const Color(0xFF3A3A3A),
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E1E1E),
            ),
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
              bodyLarge: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              bodyMedium: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              titleLarge: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              titleMedium: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              headlineSmall: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              labelLarge: GoogleFonts.poppins(color: const Color(0xFFE1E1E1), fontSize: 14),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2A2A2A), 
              labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
              hintStyle: const TextStyle(color: Color(0xFF707070)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6BB6FF), width: 2),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6BB6FF),
                foregroundColor: Colors.black,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              elevation: 0,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF6BB6FF);
                }
                return const Color(0xFF707070);
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF6BB6FF).withValues(alpha: 0.5);
                }
                return const Color(0xFF3A3A3A);
              }),
            ),
          ),
          home: AuthWrapper(themeNotifier: themeNotifier),
        );
      },
    );
  }
}