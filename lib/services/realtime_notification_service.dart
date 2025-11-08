// lib/services/realtime_notif_service.dart
// HatchTech Autonomous Real-Time Notification Service
// Monitors RTDB (HatchTech/...) for threshold violations and triggers local alerts

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class RealtimeNotificationService {
  RealtimeNotificationService._();
  static final RealtimeNotificationService instance = RealtimeNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final Map<String, Map<String, bool>> _alertState = {}; // incubator -> param -> active?
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

    final initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notificationsPlugin.initialize(initSettings);

    if (Platform.isAndroid) {
      await _createAndroidChannels();
    }

    _initialized = true;
  }

  /// Define and register channels
  Future<void> _createAndroidChannels() async {
    const channels = [
      AndroidNotificationChannel(
        'hatchtech_sensor_alerts',
        'Sensor Alerts',
        description: 'Alerts for abnormal temperature, humidity, and air quality',
        importance: Importance.high,
      ),
    ];

    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in channels) {
      await android?.createNotificationChannel(channel);
    }
  }

  /// Core listener for RTDB changes under /HatchTech/
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
          _show('🔥 Overheat Alert', '$name temperature too high: ${temp.toStringAsFixed(1)}°C');
          _alertState[name]!['tempHigh'] = true;
        } else if (temp >= 37 && _alertState[name]!['tempHigh']!) {
          _show('✅ Temperature Normal', '$name back to normal at ${temp.toStringAsFixed(1)}°C');
          _alertState[name]!['tempHigh'] = false;
        }

        if (temp < 36.5 && !_alertState[name]!['tempLow']!) {
          _show('❄️ Low Temperature', '$name too low: ${temp.toStringAsFixed(1)}°C');
          _alertState[name]!['tempLow'] = true;
        } else if (temp <= 36.5 && _alertState[name]!['tempLow']!) {
          _show('✅ Temperature Normal', '$name back to normal at ${temp.toStringAsFixed(1)}°C');
          _alertState[name]!['tempLow'] = false;
        }

        // --- Humidity ---
        if (humidity < 40 && !_alertState[name]!['humidityLow']!) {
          _show('💧 Low Humidity', '$name humidity dropped to ${humidity.toStringAsFixed(1)}%');
          _alertState[name]!['humidityLow'] = true;
        } else if (humidity >= 40 && _alertState[name]!['humidityLow']!) {
          _show('✅ Humidity Normal', '$name humidity normalized at ${humidity.toStringAsFixed(1)}%');
          _alertState[name]!['humidityLow'] = false;
        }

        if (humidity > 70 && !_alertState[name]!['humidityHigh']!) {
          _show('💦 High Humidity', '$name humidity high: ${humidity.toStringAsFixed(1)}%');
          _alertState[name]!['humidityHigh'] = true;
        } else if (humidity <= 70 && _alertState[name]!['humidityHigh']!) {
          _show('✅ Humidity Normal', '$name humidity normalized at ${humidity.toStringAsFixed(1)}%');
          _alertState[name]!['humidityHigh'] = false;
        }

        // --- CO2 ---  
        if (co2 > 1000 && !_alertState[name]!['co2High']!) {  
          _show('🌫️ CO₂ Alert', '$name CO₂ level high: ${co2.toStringAsFixed(1)} ppm');  
          _alertState[name]!['co2High'] = true;  
        } else if (co2 <= 1000 && _alertState[name]!['co2High']!) {  
        _show('✅ CO₂ Normal', '$name CO₂ level safe at ${co2.toStringAsFixed(1)} ppm');  
        _alertState[name]!['co2High'] = false;  
        }  

        // --- Oxygen ---  
        if (oxygen < 19.5 && !_alertState[name]!['oxygenLow']!) {  
          _show('🫁 Low Oxygen Alert', '$name oxygen level low: ${oxygen.toStringAsFixed(1)}%');  
          _alertState[name]!['oxygenLow'] = true;  
        } else if (oxygen >= 19.5 && _alertState[name]!['oxygenLow']!) {  
          _show('✅ Oxygen Normal', '$name oxygen back to normal at ${oxygen.toStringAsFixed(1)}%');  
          _alertState[name]!['oxygenLow'] = false;  
        }
      });
    });
  }

  /// Helper to show notification
  Future<void> _show(String title, String body) async {
    const channelId = 'hatchtech_sensor_alerts';
    final android = AndroidNotificationDetails(
      channelId,
      'Sensor Alerts',
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
