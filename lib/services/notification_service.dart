// A small wrapper around flutter_local_notifications to show notifications
// for foreground messages and create channels on Android.
// ignore_for_file: use_super_parameters

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmLocalNotificationService {
  FcmLocalNotificationService._();
  static final FcmLocalNotificationService instance = FcmLocalNotificationService._();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(initSettings,
        onDidReceiveNotificationResponse: (details) {
      // When user taps notification created by plugin
    });

    if (Platform.isAndroid) {
      await _createAndroidChannel();
    }
  }

  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      'hatchtech_default_channel',
      'HatchTech Notifications',
      description: 'Default channel for HatchTech notifications',
      importance: Importance.high,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Show a local notification populated from a [RemoteMessage]
  Future<void> showNotificationFromRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'hatchtech_default_channel',
      'HatchTech Notifications',
      channelDescription: 'Default channel for HatchTech notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    final platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformDetails,
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  }
}

class NotificationData {
  final String message;
  final Color color;
  final IconData? icon;
  final Duration duration;
  final Key key;

  NotificationData({
    required this.message,
    required this.color,
    this.icon,
    this.duration = const Duration(seconds: 3),
  }) : key = UniqueKey();
}

class _NotificationHost extends StatefulWidget {
  const _NotificationHost({Key? key}) : super(key: key);

  @override
  State<_NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends State<_NotificationHost> {
  final List<NotificationData> _items = [];

  void add(NotificationData data) {
    setState(() {
      _items.insert(0, data);
    });
    // card will handle its own timer and call remove after exit animation
  }

  void remove(Key key) {
    if (!mounted) return;
    setState(() {
      _items.removeWhere((e) => e.key == key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _items.map((data) {
          final index = _items.indexOf(data);
          return Padding(
            key: data.key,
            padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
            child: _FloatingNotificationCard(
              data: data,
              onRequestDismiss: () => remove(data.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FloatingNotificationCard extends StatefulWidget {
  final NotificationData data;
  final VoidCallback onRequestDismiss;
  const _FloatingNotificationCard({required this.data, required this.onRequestDismiss, Key? key}) : super(key: key);

  @override
  State<_FloatingNotificationCard> createState() => _FloatingNotificationCardState();
}

class _FloatingNotificationCardState extends State<_FloatingNotificationCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _offset;
  late final Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _offset = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.data.duration, _requestDismiss);
  }

  void _requestDismiss() {
    // play reverse then notify host to remove
    _ctrl.reverse().then((_) {
      widget.onRequestDismiss();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        // allow tap-to-dismiss
        _timer?.cancel();
        _requestDismiss();
      },
      child: SlideTransition(
        position: _offset,
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.data.color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Color.fromRGBO(0, 0, 0, isDark ? 0.6 : 0.2), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.data.icon != null) ...[
                      Icon(widget.data.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        widget.data.message,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// NotificationService manages a single overlay host for stacked floating notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final GlobalKey<_NotificationHostState> _hostKey = GlobalKey<_NotificationHostState>();
  OverlayEntry? _entry;

  void _ensureOverlay(BuildContext context) {
    if (_entry != null) return;
  final overlay = Overlay.of(context);
    final host = _NotificationHost(key: _hostKey);
    _entry = OverlayEntry(builder: (context) {
      return Positioned.fill(
        child: IgnorePointer(
          // we want notification cards to be tappable; allow pointer events
          ignoring: false,
          child: SafeArea(child: host),
        ),
      );
    });
    overlay.insert(_entry!);
  }

  /// Show a floating notification
  void show(BuildContext context, String message, {Color? color, IconData? icon, Duration? duration}) {
    _ensureOverlay(context);
    final data = NotificationData(
      message: message,
      color: color ?? Colors.blueAccent,
      icon: icon,
      duration: duration ?? const Duration(seconds: 3),
    );
    _hostKey.currentState?.add(data);
  }
}
