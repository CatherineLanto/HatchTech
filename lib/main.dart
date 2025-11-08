// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import 'firebase_options.dart';
import 'auth_wrapper.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/realtime_notification_service.dart'; // ✅ your new file

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FcmLocalNotificationService.instance.init();
  await FcmLocalNotificationService.instance.showNotificationFromRemoteMessage(message);
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize local notifications
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // Request notification permissions
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Handle FCM background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Retrieve FCM token
  final fcmToken = await FirebaseMessaging.instance.getToken();
  print('📱 FCM Token: $fcmToken');

  // Save token to Firestore + RTDB
  try {
    final user = AuthService.currentUser;
    if (user != null && fcmToken != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'fcmToken': fcmToken});
      await FirebaseDatabase.instance.ref('fcmTokens/${user.uid}').set(fcmToken);
    }
  } catch (e) {
    print('⚠️ Error saving FCM token: $e');
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

    // ✅ Initialize local notifications
    FcmLocalNotificationService.instance.init();

    // ✅ Start real-time listener
    RealtimeNotificationService.instance.init();
    RealtimeNotificationService.instance.startListening();


    // ✅ Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Foreground FCM received: ${message.data}');
      final data = message.data;
      final title = data['title'] ?? message.notification?.title ?? 'HatchTech Alert';
      final body = data['body'] ?? message.notification?.body ?? 'Check incubator status.';

      FcmLocalNotificationService.instance.showNotification(
        title: title,
        body: body,
        type: data['type'] ?? 'general',
      );
    });

    // ✅ Handle app opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) print('🚀 App opened from terminated state by notification');
    });

    // ✅ Handle background tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('📬 Notification caused app to open');
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