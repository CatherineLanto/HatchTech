// lib/services/realtime_notif_service.dart
// HatchTech Autonomous Real-Time Notification Service
// Monitors RTDB (HatchTech/...) for threshold violations and Firestore for batch schedules

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class RealtimeNotificationService {
  RealtimeNotificationService._();
  static final RealtimeNotificationService instance = RealtimeNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final Map<String, Map<String, bool>> _alertState = {}; // incubator -> param -> active?
  final Map<String, bool> _batchAlertState = {}; // batch-based alert tracker
  bool _initialized = false;
  bool _firstSnapshotSkipped = false;

  /// Initialize notification channels and permissions
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notificationsPlugin.initialize(initSettings);

    if (Platform.isAndroid) {
      await _createAndroidChannels();
    }

    _initialized = true;
  }

  /// Define and register notification channels
  Future<void> _createAndroidChannels() async {
    const channels = [
      AndroidNotificationChannel(
        'hatchtech_sensor_alerts',
        'Sensor Alerts',
        description: 'Alerts for abnormal temperature, humidity, and air quality',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'hatchtech_batch_reminders',
        'Batch Reminders',
        description: 'Candling and hatching reminders for active batches',
        importance: Importance.high,
      ),
    ];

    final androidImpl =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    for (final c in channels) {
      await androidImpl?.createNotificationChannel(c);
    }
  }

  // ---------------------------------------------------------------------------
  // REALTIME DATABASE MONITORING (for sensor thresholds)
  // ---------------------------------------------------------------------------
  void startListening() {
    final ref = FirebaseDatabase.instance.ref('HatchTech');

    ref.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      // Avoid flooding on initial full snapshot
      if (!_firstSnapshotSkipped) {
        _firstSnapshotSkipped = true;
        return;
      }

      data.forEach((key, value) {
        final incubator = value as Map?;
        if (incubator == null) return;
        final name = key.toString();

        // Initialize alert states for this incubator
        _alertState.putIfAbsent(name, () => {
              'tempHigh': false,
              'tempLow': false,
              'humidityLow': false,
              'humidityHigh': false,
              'co2High': false,
              'oxygenLow': false,
            });

        final temp = double.tryParse(incubator['temperature']?.toString() ?? '0') ?? 0;
        final humidity = double.tryParse(incubator['humidity']?.toString() ?? '0') ?? 0;
        final co2 = double.tryParse(incubator['co2']?.toString() ?? '0') ?? 0;
        final oxygen = double.tryParse(incubator['oxygen']?.toString() ?? '0') ?? 0;

        // --- Temperature ---
        if (temp > 39 && !_alertState[name]!['tempHigh']!) {
          _show(
              '🔥 Overheat Alert',
              '$name temperature too high: ${temp.toStringAsFixed(1)}°C',
              'hatchtech_sensor_alerts');
          _alertState[name]!['tempHigh'] = true;
        } else if (temp >= 37 && _alertState[name]!['tempHigh']!) {
          _show(
              '✅ Temperature Normal',
              '$name back to normal at ${temp.toStringAsFixed(1)}°C',
              'hatchtech_sensor_alerts');
          _alertState[name]!['tempHigh'] = false;
        }

        if (temp < 36.5 && !_alertState[name]!['tempLow']!) {
          _show('❄️ Low Temperature',
              '$name too low: ${temp.toStringAsFixed(1)}°C', 'hatchtech_sensor_alerts');
          _alertState[name]!['tempLow'] = true;
        } else if (temp >= 36.5 && _alertState[name]!['tempLow']!) {
          _show(
              '✅ Temperature Normal',
              '$name back to normal at ${temp.toStringAsFixed(1)}°C',
              'hatchtech_sensor_alerts');
          _alertState[name]!['tempLow'] = false;
        }

        // --- Humidity ---
        if (humidity < 40 && !_alertState[name]!['humidityLow']!) {
          _show('💧 Low Humidity',
              '$name humidity dropped to ${humidity.toStringAsFixed(1)}%',
              'hatchtech_sensor_alerts');
          _alertState[name]!['humidityLow'] = true;
        } else if (humidity >= 40 && _alertState[name]!['humidityLow']!) {
          _show('✅ Humidity Normal',
              '$name humidity normalized at ${humidity.toStringAsFixed(1)}%',
              'hatchtech_sensor_alerts');
          _alertState[name]!['humidityLow'] = false;
        }

        if (humidity > 70 && !_alertState[name]!['humidityHigh']!) {
          _show('💦 High Humidity',
              '$name humidity high: ${humidity.toStringAsFixed(1)}%',
              'hatchtech_sensor_alerts');
          _alertState[name]!['humidityHigh'] = true;
        } else if (humidity <= 70 && _alertState[name]!['humidityHigh']!) {
          _show('✅ Humidity Normal',
              '$name humidity normalized at ${humidity.toStringAsFixed(1)}%',
              'hatchtech_sensor_alerts');
          _alertState[name]!['humidityHigh'] = false;
        }

        // --- CO2 ---
        if (co2 > 1000 && !_alertState[name]!['co2High']!) {
          _show('🌫️ CO₂ Alert',
              '$name CO₂ level high: ${co2.toStringAsFixed(1)} ppm',
              'hatchtech_sensor_alerts');
          _alertState[name]!['co2High'] = true;
        } else if (co2 <= 1000 && _alertState[name]!['co2High']!) {
          _show('✅ CO₂ Normal',
              '$name CO₂ level safe at ${co2.toStringAsFixed(1)} ppm',
              'hatchtech_sensor_alerts');
          _alertState[name]!['co2High'] = false;
        }

        // --- Oxygen ---
        if (oxygen < 19.5 && !_alertState[name]!['oxygenLow']!) {
          _show('🫁 Low Oxygen Alert',
              '$name oxygen level low: ${oxygen.toStringAsFixed(1)}%',
              'hatchtech_sensor_alerts');
          _alertState[name]!['oxygenLow'] = true;
        } else if (oxygen >= 19.5 && _alertState[name]!['oxygenLow']!) {
          _show('✅ Oxygen Normal',
              '$name oxygen back to normal at ${oxygen.toStringAsFixed(1)}%',
              'hatchtech_sensor_alerts');
          _alertState[name]!['oxygenLow'] = false;
        }
      });
    });
  }

  // ---------------------------------------------------------------------------
  // FIRESTORE MONITORING (for batch candling & hatching reminders)
  // ---------------------------------------------------------------------------
  void startBatchReminderListener() {
    final firestore = FirebaseFirestore.instance.collection('batchHistory');

    firestore.snapshots().listen((snapshot) {
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.isEmpty) continue;

        final batchName = data['batchName'] ?? 'Unnamed Batch';
        final incubator = data['incubatorName'] ?? 'Unknown Incubator';
        final incubationDays = data['incubationDays'] ?? 21;
        final startDateMillis = data['startDate'];

        if (startDateMillis == null) continue;
        final startDate =
            DateTime.fromMillisecondsSinceEpoch(startDateMillis);
        final hatchDate = startDate.add(Duration(days: incubationDays));

        final daysToHatch = hatchDate.difference(now).inDays;

        // Initialize state
        _batchAlertState.putIfAbsent(batchName, () => false);

        // --- Hatching Reminder ---
        if (daysToHatch <= 1 && !_batchAlertState[batchName]!) {
          _show('🐣 Hatching Soon!',
              '$batchName in $incubator will hatch in $daysToHatch day(s)!',
              'hatchtech_batch_reminders');
          _batchAlertState[batchName] = true;
        }

        // --- Candling Reminders ---
        if (data['candlingDates'] != null && data['candlingDates'] is Map) {
          final candling = Map<String, dynamic>.from(data['candlingDates']);
          final daysSinceStart = now.difference(startDate).inDays;

          candling.forEach((day, done) {
            if (!done &&
                int.tryParse(day) != null &&
                daysSinceStart >= int.parse(day)) {
              _show(
                '🔦 Candling Reminder',
                '$batchName in $incubator is due for candling (Day $day).',
                'hatchtech_batch_reminders',
              );
              // Optional: update Firestore to mark as notified
              // firestore.doc(doc.id).update({'candlingDates.$day': true});
            }
          });
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Helper to show local notification
  // ---------------------------------------------------------------------------
  Future<void> _show(String title, String body, String channelId) async {
    final android = AndroidNotificationDetails(
      channelId,
      'HatchTech Alerts',
      importance: Importance.high,
      priority: Priority.high,
      color: Colors.redAccent,
      icon: '@mipmap/ic_launcher',
    );
    const ios = DarwinNotificationDetails();

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
  }
}
