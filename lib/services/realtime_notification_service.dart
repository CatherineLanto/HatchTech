// ignore_for_file: avoid_print

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

  final Map<String, Map<String, bool>> _alertState = {}; 
  final Map<String, bool> _batchAlertState = {}; 
  
  // Map to track the last time a notification was shown (in milliseconds)
  final Map<String, int> _cooldownTimestamps = {}; 
  static const int _cooldownDuration = 5 * 60 * 1000; // 5 minutes in milliseconds

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
  
  // Helper: Checks the time-based cooldown
  bool _canShowAlert(String uniqueAlertKey) {
    final lastTime = _cooldownTimestamps[uniqueAlertKey] ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check if the difference is greater than the cooldown duration
    return (now - lastTime) > _cooldownDuration;
  }
  
  // Helper: Updates the cooldown time
  void _updateCooldown(String uniqueAlertKey) {
    _cooldownTimestamps[uniqueAlertKey] = DateTime.now().millisecondsSinceEpoch;
  }

  void startListening() {
    final ref = FirebaseDatabase.instance.ref('HatchTech');

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

        // --- SENSOR CHECKS ---
        
        // Temperature High Check
        const tempHighKey = 'tempHigh';
        const tempHighResetKey = 'tempHigh_RESET';

        if (temp > 39 && !_alertState[name]![tempHighKey]!) {
          if (_canShowAlert('$name/$tempHighKey')) { 
            _show('🔥 Overheat Alert', '$name temperature too high: ${temp.toStringAsFixed(1)}°C', 'hatchtech_sensor_alerts');
            _updateCooldown('$name/$tempHighKey'); 
          }
          _alertState[name]![tempHighKey] = true;
          
        } else if (temp <= 39 && _alertState[name]![tempHighKey]!) {
          if (_canShowAlert('$name/$tempHighResetKey')) { 
            _show('✅ Temperature Normal', '$name back to normal at ${temp.toStringAsFixed(1)}°C', 'hatchtech_sensor_alerts');
            _updateCooldown('$name/$tempHighResetKey');
          }
          _alertState[name]![tempHighKey] = false;
        }

        // Temperature Low Check
        const tempLowKey = 'tempLow';
        const tempLowResetKey = 'tempLow_RESET';

        if (temp < 36.5 && !_alertState[name]![tempLowKey]!) {
          if (_canShowAlert('$name/$tempLowKey')) {
            _show('❄️ Low Temperature', '$name too low: ${temp.toStringAsFixed(1)}°C', 'hatchtech_sensor_alerts');
            _updateCooldown('$name/$tempLowKey');
          }
          _alertState[name]![tempLowKey] = true;
          
        } else if (temp >= 36.5 && _alertState[name]![tempLowKey]!) {
          if (_canShowAlert('$name/$tempLowResetKey')) { 
            _show('✅ Temperature Normal', '$name back to normal at ${temp.toStringAsFixed(1)}°C', 'hatchtech_sensor_alerts');
            _updateCooldown('$name/$tempLowResetKey');
          }
          _alertState[name]![tempLowKey] = false;
        }
        
        // Humidity Low Check
        const humidityLowKey = 'humidityLow';
        const humidityLowResetKey = 'humidityLow_RESET';
        if (humidity < 40 && !_alertState[name]![humidityLowKey]!) {
          if (_canShowAlert('$name/$humidityLowKey')) {
            _show('💧 Low Humidity', '$name humidity dropped to ${humidity.toStringAsFixed(1)}%', 'hatchtech_sensor_alerts');
            _updateCooldown('$name/$humidityLowKey');
          }
          _alertState[name]![humidityLowKey] = true;
        } else if (humidity >= 40 && _alertState[name]![humidityLowKey]!) {
          if (_canShowAlert('$name/$humidityLowResetKey')) {
            _show('✅ Humidity Normal', '$name humidity normalized at ${humidity.toStringAsFixed(1)}%', 'hatchtech_sensor_alerts');
            _updateCooldown('$name/$humidityLowResetKey');
          }
          _alertState[name]![humidityLowKey] = false;
        }

        // Humidity High Check
        const humidityHighKey = 'humidityHigh';
        const humidityHighResetKey = 'humidityHigh_RESET';
        if (humidity > 70 && !_alertState[name]![humidityHighKey]!) {
          if (_canShowAlert('$name/$humidityHighKey')) {
            _show('💦 High Humidity', '$name humidity high: ${humidity.toStringAsFixed(1)}%', 'hatchtech_sensor_alerts');
            _updateCooldown('$name/$humidityHighKey');
          }
          _alertState[name]![humidityHighKey] = true;
        } else if (humidity <= 70 && _alertState[name]![humidityHighKey]!) {
          if (_canShowAlert('$name/$humidityHighResetKey')) {
            _show('✅ Humidity Normal', '$name humidity normalized at ${humidity.toStringAsFixed(1)}%', 'hatchtech_sensor_alerts');
            _updateCooldown('$name/$humidityHighResetKey');
          }
          _alertState[name]![humidityHighKey] = false;
        }

        // CO2 High Check
        const co2HighKey = 'co2High';
        const co2HighResetKey = 'co2High_RESET';
        if (co2 > 1000 && !_alertState[name]![co2HighKey]!) {
          if (_canShowAlert('$name/$co2HighKey')) {
            _show('🌫️ CO₂ Alert', '$name CO₂ level high: ${co2.toStringAsFixed(1)} ppm', 'hatchtech_sensor_alerts');
            _updateCooldown('$name/$co2HighKey');
          }
          _alertState[name]![co2HighKey] = true;
        } else if (co2 <= 1000 && _alertState[name]![co2HighKey]!) {
          if (_canShowAlert('$name/$co2HighResetKey')) {
            _show('✅ CO₂ Normal', '$name CO₂ level safe at ${co2.toStringAsFixed(1)} ppm', 'hatchtech_sensor_alerts');
            _updateCooldown('$name/$co2HighResetKey');
          }
          _alertState[name]![co2HighKey] = false;
        }

        // Oxygen Low Check
        const oxygenLowKey = 'oxygenLow';
        const oxygenLowResetKey = 'oxygenLow_RESET';
        if (oxygen < 19 && !_alertState[name]![oxygenLowKey]!) {
          if (_canShowAlert('$name/$oxygenLowKey')) {
            _show('🫁 Low Oxygen Alert', '$name oxygen level low: ${oxygen.toStringAsFixed(1)}%', 'hatchtech_sensor_alerts');
            _updateCooldown('$name/$oxygenLowKey');
          }
          _alertState[name]![oxygenLowKey] = true;
        } else if (oxygen >= 19.5 && _alertState[name]![oxygenLowKey]!) {
          if (_canShowAlert('$name/$oxygenLowResetKey')) {
            _show('✅ Oxygen Normal', '$name oxygen back to normal at ${oxygen.toStringAsFixed(1)}%', 'hatchtech_sensor_alerts');
            _updateCooldown('$name/$oxygenLowResetKey');
          }
          _alertState[name]![oxygenLowKey] = false;
        }

        // --- MAINTENANCE CHECKS ---

        final maintenanceData = incubator['maintenance'] as Map?;
        if (maintenanceData != null) {
          
          // Fan Maintenance Alert
          const fanKey = 'maintenanceFan';
          const fanResetKey = 'maintenanceFan_RESET';
          final fanMaintenance = maintenanceData['fan']?.toString();
          
          if (fanMaintenance != null && !_alertState[name]![fanKey]!) {
            if (_canShowAlert('$name/$fanKey')) {
              _show(
                  '⚠️ Predictive Maintenance: Fan',
                  '$name: $fanMaintenance',
                  'hatchtech_maintenance_alerts');
              _updateCooldown('$name/$fanKey');
            }
            _alertState[name]![fanKey] = true;
            
          } else if (fanMaintenance == null && _alertState[name]![fanKey]!) {
            if (_canShowAlert('$name/$fanResetKey')) {
               _show('✅ Maintenance Complete', '$name: Fan maintenance completed.', 'hatchtech_maintenance_alerts');
               _updateCooldown('$name/$fanResetKey');
            }
            _alertState[name]![fanKey] = false;
          }

          // Sensor Maintenance Alert 
          const sensorKey = 'maintenanceSensor';
          const sensorResetKey = 'maintenanceSensor_RESET';
          final sensorMaintenance = maintenanceData['sensor']?.toString();
          
          if (sensorMaintenance != null && !_alertState[name]![sensorKey]!) {
            if (_canShowAlert('$name/$sensorKey')) {
              _show(
                  '⚠️ Predictive Maintenance: Sensor',
                  '$name: $sensorMaintenance',
                  'hatchtech_maintenance_alerts');
              _updateCooldown('$name/$sensorKey');
            }
            _alertState[name]![sensorKey] = true;
            
          } else if (sensorMaintenance == null && _alertState[name]![sensorKey]!) {
            if (_canShowAlert('$name/$sensorResetKey')) {
               _show('✅ Maintenance Complete', '$name: Sensor maintenance completed.', 'hatchtech_maintenance_alerts');
               _updateCooldown('$name/$sensorResetKey');
            }
            _alertState[name]![sensorKey] = false;
          }

          // Motor Maintenance Alert 
          const motorKey = 'maintenanceMotor';
          const motorResetKey = 'maintenanceMotor_RESET';
          final motorMaintenance = maintenanceData['motor']?.toString();
          
          if (motorMaintenance != null && !_alertState[name]![motorKey]!) {
            if (_canShowAlert('$name/$motorKey')) {
              _show(
                  '⚠️ Predictive Maintenance: Motor',
                  '$name: $motorMaintenance',
                  'hatchtech_maintenance_alerts');
              _updateCooldown('$name/$motorKey');
            }
            _alertState[name]![motorKey] = true;
            
          } else if (motorMaintenance == null && _alertState[name]![motorKey]!) {
            if (_canShowAlert('$name/$motorResetKey')) {
               _show('✅ Maintenance Complete', '$name: Motor maintenance completed.', 'hatchtech_maintenance_alerts');
               _updateCooldown('$name/$motorResetKey');
            }
            _alertState[name]![motorKey] = false;
          }

        } else {
            // Ensure state is reset if the entire maintenance node disappears
            _alertState[name]!['maintenanceFan'] = false;
            _alertState[name]!['maintenanceSensor'] = false;
            _alertState[name]!['maintenanceMotor'] = false;
        }
      });
    });
  }

  void startBatchReminderListener() {
    final firestore = FirebaseFirestore.instance.collection('batchHistory');

    firestore.where('isDone', isEqualTo: false).snapshots().listen((snapshot) {
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
        const hatchKey = 'hatchingSoon';

        _batchAlertState.putIfAbsent(batchName, () => false);

        // Hatching Reminder Check
        if (daysToHatch <= 1 && !_batchAlertState[batchName]!) {
          if (_canShowAlert('$batchName/$hatchKey')) { 
            _show('🐣 Hatching Soon!',
                '$batchName in $incubator will hatch in $daysToHatch day(s)!',
                'hatchtech_batch_reminders');
            _updateCooldown('$batchName/$hatchKey'); 
            _batchAlertState[batchName] = true; 
          }
        } 
        // Note: The state remains true until the condition is no longer met (i.e., daysToHatch > 1) 
        // or the document is marked as done. This handles the state correctly.


        // Candling Reminder Check
        const candlingKey = 'candlingDue';
        if (data['candlingDates'] != null && data['candlingDates'] is Map) {
          final candling = Map<String, dynamic>.from(data['candlingDates']);
          final daysSinceStart = now.difference(startDate).inDays;

          candling.forEach((day, done) {
            // Create a unique key for each candling day (e.g., BatchA/candlingDue_7)
            final uniqueCandlingKey = '$batchName/${candlingKey}_$day'; 
            
            if (!done &&
                int.tryParse(day) != null &&
                daysSinceStart >= int.parse(day)) {
              
              if (_canShowAlert(uniqueCandlingKey)) { 
                _show(
                  '🔦 Candling Reminder',
                  '$batchName in $incubator is due for candling (Day $day).',
                  'hatchtech_batch_reminders',
                );
                _updateCooldown(uniqueCandlingKey); 
              }
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