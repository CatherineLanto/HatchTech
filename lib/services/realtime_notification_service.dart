// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RealtimeNotificationService {
  RealtimeNotificationService._();
  static final RealtimeNotificationService instance = RealtimeNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final Map<String, Map<String, bool>> _alertState = {}; 
  final Map<String, bool> _batchAlertState = {}; 
  bool _initialized = false;
  bool _firstSnapshotSkipped = false;

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
      AndroidNotificationChannel( 
        'hatchtech_maintenance_alerts', 
        'Maintenance Alerts', 
        description: 'Predictive and scheduled maintenance reminders', 
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

  void startListening() {
    final ref = FirebaseDatabase.instance.ref('HatchTech');
    if (FirebaseAuth.instance.currentUser == null) {
      print('Skipping Realtime DB notification: User not logged in.');
      return; 
    }

    ref.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      if (!_firstSnapshotSkipped) {
        _firstSnapshotSkipped = true;
        return;
      }

      data.forEach((key, value) {
        final incubator = value as Map?;
        if (incubator == null) return;
        final name = key.toString();

        _alertState.putIfAbsent(name, () => {
          'tempHigh': false,
          'tempLow': false,
          'humidityLow': false,
          'humidityHigh': false,
          'co2High': false,
          'oxygenLow': false,
          'maintenanceFan': false,
          'maintenanceSensor': false,
          'maintenanceMotor': false,
        });

        final temp = double.tryParse(incubator['temperature']?.toString() ?? '0') ?? 0;
        final humidity = double.tryParse(incubator['humidity']?.toString() ?? '0') ?? 0;
        final co2 = double.tryParse(incubator['co2']?.toString() ?? '0') ?? 0;
        final oxygen = double.tryParse(incubator['oxygen']?.toString() ?? '0') ?? 0;

        // Temperature High Check
        if (temp > 39 && !_alertState[name]!['tempHigh']!) {
          _show('🔥 Overheat Alert', '$name temperature too high: ${temp.toStringAsFixed(1)}°C', 'hatchtech_sensor_alerts');
          _alertState[name]!['tempHigh'] = true;
        } else if (temp <= 39 && _alertState[name]!['tempHigh']!) {
          _show('✅ Temperature Normal', '$name back to normal at ${temp.toStringAsFixed(1)}°C', 'hatchtech_sensor_alerts');
          _alertState[name]!['tempHigh'] = false;
        }

        // Temperature Low Check
        if (temp < 36.5 && !_alertState[name]!['tempLow']!) {
            _show('❄️ Low Temperature', '$name too low: ${temp.toStringAsFixed(1)}°C', 'hatchtech_sensor_alerts');
          _alertState[name]!['tempLow'] = true;
        } else if (temp >= 36.5 && _alertState[name]!['tempLow']!) {
          _show('✅ Temperature Normal', '$name back to normal at ${temp.toStringAsFixed(1)}°C', 'hatchtech_sensor_alerts');
          _alertState[name]!['tempLow'] = false;
        }

        // Humidity Low Check
        if (humidity < 40 && !_alertState[name]!['humidityLow']!) {
          _show('💧 Low Humidity', '$name humidity dropped to ${humidity.toStringAsFixed(1)}%', 'hatchtech_sensor_alerts');
          _alertState[name]!['humidityLow'] = true;
        } else if (humidity >= 40 && _alertState[name]!['humidityLow']!) {
          _show('✅ Humidity Normal', '$name humidity normalized at ${humidity.toStringAsFixed(1)}%', 'hatchtech_sensor_alerts');
          _alertState[name]!['humidityLow'] = false;
        }

        // Humidity High Check
        if (humidity > 70 && !_alertState[name]!['humidityHigh']!) {
          _show('💦 High Humidity', '$name humidity high: ${humidity.toStringAsFixed(1)}%', 'hatchtech_sensor_alerts');
          _alertState[name]!['humidityHigh'] = true;
        } else if (humidity <= 70 && _alertState[name]!['humidityHigh']!) {
          _show('✅ Humidity Normal', '$name humidity normalized at ${humidity.toStringAsFixed(1)}%', 'hatchtech_sensor_alerts');
          _alertState[name]!['humidityHigh'] = false;
        }

        // CO2 High Check
        if (co2 > 1000 && !_alertState[name]!['co2High']!) {
          _show('🌫️ CO₂ Alert', '$name CO₂ level high: ${co2.toStringAsFixed(1)} ppm', 'hatchtech_sensor_alerts');
          _alertState[name]!['co2High'] = true;
        } else if (co2 <= 1000 && _alertState[name]!['co2High']!) {
          _show('✅ CO₂ Normal', '$name CO₂ level safe at ${co2.toStringAsFixed(1)} ppm', 'hatchtech_sensor_alerts');
          _alertState[name]!['co2High'] = false;
        }

        // Oxygen Low Check
        if (oxygen < 19 && !_alertState[name]!['oxygenLow']!) {
          _show('🫁 Low Oxygen Alert', '$name oxygen level low: ${oxygen.toStringAsFixed(1)}%', 'hatchtech_sensor_alerts');
          _alertState[name]!['oxygenLow'] = true;
        } else if (oxygen >= 19.5 && _alertState[name]!['oxygenLow']!) {
          _show('✅ Oxygen Normal', '$name oxygen back to normal at ${oxygen.toStringAsFixed(1)}%', 'hatchtech_sensor_alerts');
          _alertState[name]!['oxygenLow'] = false;
        }

        final maintenanceData = incubator['maintenance'] as Map?;
        if (maintenanceData != null) {
          final fanMaintenance = maintenanceData['fan']?.toString();
          final sensorMaintenance = maintenanceData['sensor']?.toString();
          final motorMaintenance = maintenanceData['motor']?.toString();

          // Fan Maintenance Alert
          if (fanMaintenance != null && !_alertState[name]!['maintenanceFan']!) {
            _show(
                '⚠️ Predictive Maintenance: Fan',
                '$name: $fanMaintenance',
                'hatchtech_maintenance_alerts');
            _alertState[name]!['maintenanceFan'] = true;
          } else if (fanMaintenance == null && _alertState[name]!['maintenanceFan']!) {
            _alertState[name]!['maintenanceFan'] = false;
          }

          // Sensor Maintenance Alert 
          if (sensorMaintenance != null && !_alertState[name]!['maintenanceSensor']!) {
            _show(
                '⚠️ Predictive Maintenance: Sensor',
                '$name: $sensorMaintenance',
                'hatchtech_maintenance_alerts');
            _alertState[name]!['maintenanceSensor'] = true;
          } else if (sensorMaintenance == null && _alertState[name]!['maintenanceSensor']!) {
            _alertState[name]!['maintenanceSensor'] = false;
          }

          // Motor Maintenance Alert 
          if (motorMaintenance != null && !_alertState[name]!['maintenanceMotor']!) {
            _show(
                '⚠️ Predictive Maintenance: Motor',
                '$name: $motorMaintenance',
                'hatchtech_maintenance_alerts');
            _alertState[name]!['maintenanceMotor'] = true;
          } else if (motorMaintenance == null && _alertState[name]!['maintenanceMotor']!) {
            _alertState[name]!['maintenanceMotor'] = false;
          }

        } else {
            _alertState[name]!['maintenanceFan'] = false;
            _alertState[name]!['maintenanceSensor'] = false;
            _alertState[name]!['maintenanceMotor'] = false;
        }
      });
    });
  }

  void startBatchReminderListener() {
    if (FirebaseAuth.instance.currentUser == null) {
        print('Skipping Batch Reminder listener: User not logged in.');
        return; 
    }
    final firestore = FirebaseFirestore.instance.collection('incubators');

    firestore.where('isDone', isEqualTo: false).snapshots().listen((snapshot) {
      if (FirebaseAuth.instance.currentUser == null) {
        print('Skipping Batch Reminder notification: User logged out.');
        return;
      }
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

        _batchAlertState.putIfAbsent(batchName, () => false);

        if (daysToHatch <= 1 && !_batchAlertState[batchName]!) {
          _show('🐣 Hatching Soon!',
              '$batchName in $incubator will hatch in $daysToHatch day(s)!',
              'hatchtech_batch_reminders');
          _batchAlertState[batchName] = true;
        }

        if (data['candlingDates'] != null && data['candlingDates'] is Map) {
          final candling = Map<String, dynamic>.from(data['candlingDates']);
          final daysSinceStart = now.difference(startDate).inDays;

          candling.forEach((day, done) {
            if (!done &&
                int.tryParse(day) != null &&
                daysSinceStart >= int.parse(day)) {
              _show(
                '🔦 Candling Reminder',
                '$batchName in $incubator is due for candling.',
                'hatchtech_batch_reminders',
              );
            }
          });
        }
      }
    });
  }

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
