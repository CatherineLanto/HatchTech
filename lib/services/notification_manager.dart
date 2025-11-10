import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationManager {
  static final NotificationManager instance = NotificationManager._internal();
  NotificationManager._internal();

  final _messaging = FirebaseMessaging.instance;
  final _firestore = FirebaseFirestore.instance;
  final _rtdb = FirebaseDatabase.instance.ref('HatchTech');
  final _local = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    final initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _local.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'hatchtech_alerts',
      'HatchTech Alerts',
      description: 'Sensor and batch notifications',
      importance: Importance.high,
    );
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);

    await _messaging.requestPermission();

    await _saveUserFcmToken();

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    FirebaseMessaging.onMessage.listen((message) {
      final notif = message.notification;
      if (notif != null) {
        _showLocal(notif.title ?? 'HatchTech', notif.body ?? '');
      }
    });

    _listenRealtime();

    _initialized = true;
  }

  Future<void> _saveUserFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'fcm_token': token,
      'last_token_update': FieldValue.serverTimestamp(),
    });

    _messaging.onTokenRefresh.listen((newToken) async {
      await _firestore.collection('users').doc(user.uid).update({
        'fcm_token': newToken,
        'last_token_update': FieldValue.serverTimestamp(),
      });
    });
  }

  void _listenRealtime() {
    _rtdb.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      data.forEach((key, val) {
        final incubator = val as Map?;
        if (incubator == null) return;

        final name = key.toString();
        final temp = double.tryParse(incubator['temperature']?.toString() ?? '0') ?? 0;
        final humidity = double.tryParse(incubator['humidity']?.toString() ?? '0') ?? 0;

        if (temp > 39) {
          _showLocal('🔥 Overheat Alert',
              '$name temperature too high (${temp.toStringAsFixed(1)}°C)');
        } else if (temp < 36) {
          _showLocal('❄️ Low Temperature',
              '$name temperature too low (${temp.toStringAsFixed(1)}°C)');
        }

        if (humidity < 40) {
          _showLocal('💧 Low Humidity',
              '$name humidity dropped (${humidity.toStringAsFixed(1)}%)');
        } else if (humidity > 70) {
          _showLocal('💦 High Humidity',
              '$name humidity too high (${humidity.toStringAsFixed(1)}%)');
        }
      });
    });
  }

  Future<void> _showLocal(String title, String body) async {
    const channelId = 'hatchtech_alerts';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'HatchTech Alerts',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}

Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  final plugin = FlutterLocalNotificationsPlugin();
  final notif = message.notification;
  if (notif != null) {
    const channelId = 'hatchtech_alerts';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'HatchTech Alerts',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
    await plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notif.title ?? 'HatchTech',
      notif.body ?? '',
      details,
    );
  }
}
