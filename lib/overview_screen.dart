// ignore_for_file: avoid_print

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'profile_screen.dart';
import 'utils/analytics_helper.dart';
import 'services/notification_service.dart';
import 'maintenance_log.dart';


class OverviewPage extends StatefulWidget {
  final String userName;
  final ValueNotifier<ThemeMode> themeNotifier;
  final Map<String, Map<String, dynamic>>? sharedIncubatorData;
  final List<Map<String, dynamic>>? batchHistory;
  final Function(Map<String, Map<String, dynamic>>)? onDataChanged;
  final Function(String)? onUserNameChanged;
  final Function(String)? onNavigateToDashboard;
  final VoidCallback? onNavigateToAnalytics;
  final String? userRole;
  final dynamic onNavigateToMaintenance;

  const OverviewPage({
    super.key,
    required this.userName,
    required this.themeNotifier,
    this.sharedIncubatorData,
    this.batchHistory,
    this.onDataChanged,
    this.onUserNameChanged,
    this.onNavigateToDashboard,
    this.onNavigateToAnalytics,
    this.userRole,
    this.onNavigateToMaintenance,
  });

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  DateTime? _lastHatchNotification;
  DateTime? _lastWarningNotification;
  final Map<String, DateTime> _lastCandlingNotification = {};
  // Modern notification helper
  void showModernNotification(String message, {Color? color, IconData? icon}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().show(
        context,
        message,
        color: color ?? Colors.blueAccent,
        icon: icon,
      );
    });
  }
  bool get isOwnerOrAdmin {
    final roleLower = (widget.userRole ?? '').toLowerCase();
    return roleLower.contains('owner') || roleLower.contains('admin');
  }
  StreamSubscription? _incubatorSub;
  StreamSubscription? _batchHistorySub;
  List<Map<String, dynamic>> _localBatchHistory = [];
  late String userName;
  bool isNewUser = false;
  int normalCount = 0;
  int warningCount = 0;
  List<String> incubators = [];

  Map<String, Map<String, dynamic>> incubatorData = {};

  List<String> normalIncubators = [];
  List<String> warningIncubators = [];
  Map<String, List<String>> warningDetails = {};

  @override
  void initState() {
    super.initState();
    userName = widget.userName;
    
    _incubatorSub = FirebaseFirestore.instance.collection('incubators').snapshots().listen((snapshot) {
      final Map<String, Map<String, dynamic>> fetchedData = {};
      for (var doc in snapshot.docs) {
        fetchedData[doc.id] = Map<String, dynamic>.from(doc.data());
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            incubatorData = fetchedData;
            incubators = incubatorData.keys.toList();
          });
          _updateCounts();
        }
      });
    });
    // Listen to batch history similar to AnalyticsScreen so Overview reflects same data
    _batchHistorySub = FirebaseFirestore.instance.collection('batchHistory').snapshots().listen((snapshot) {
      final List<Map<String, dynamic>> fetchedHistory = [];
      for (var doc in snapshot.docs) {
        fetchedHistory.add(Map<String, dynamic>.from(doc.data()));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _localBatchHistory = fetchedHistory;
        });
      });
    });
    
    _loadFirebaseUserData();
  }

  @override
  void dispose() {
  _incubatorSub?.cancel();
  _batchHistorySub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(OverviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.sharedIncubatorData != oldWidget.sharedIncubatorData) {
      debugPrint('OverviewScreen: Shared incubator data updated');
      if (widget.sharedIncubatorData != null && widget.sharedIncubatorData!.isNotEmpty) {
        setState(() {
          incubatorData = Map.from(widget.sharedIncubatorData!);
          incubators = incubatorData.keys.toList();
        });
        _updateCounts();
      }
    }
  }

  Map<String, Map<String, dynamic>> get _currentIncubatorData {
    return widget.sharedIncubatorData ?? incubatorData;
  }
  
  get selectedIncubator => null;
  get currentUserName => null;

  Future<void> _loadFirebaseUserData() async {
    try {
      final userData = await AuthService.getUserData();
      if (userData != null && mounted) {
        final firebaseUsername = userData['username'];
        if (firebaseUsername != null && firebaseUsername != userName) {
          setState(() {
            userName = firebaseUsername;
          });
          widget.onUserNameChanged?.call(userName);
        }
      }

      final userIsNew = await AuthService.isNewUser();
      if (mounted) {
        setState(() {
          isNewUser = userIsNew;
        });
      }
    } catch (e) {
      // Handle error silently and keep existing username
    }
  }

  void updateIncubatorData(Map<String, Map<String, dynamic>> newData) {
    if (mounted) {
      setState(() {
        incubatorData = Map.from(newData);
        incubators = newData.keys.toList();
        _updateCounts();
      });
      
      if (widget.onDataChanged != null) {
        widget.onDataChanged!(Map.from(incubatorData));
      }
    }
  }

  void _updateCounts() {
    // Hatching date notifications (<=2 days left)
    final now = DateTime.now();
    for (final name in incubators) {
      final data = _currentIncubatorData[name];
      if (data != null) {
        final int startDateMs = data['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
        final int incubationDays = data['incubationDays'] ?? 21;
        final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
        final int daysElapsed = now.difference(startDate).inDays;
        final int daysRemaining = (incubationDays - daysElapsed).clamp(0, incubationDays);
        if (daysRemaining <= 2 && daysRemaining > 0) {
          if (_lastHatchNotification == null || now.difference(_lastHatchNotification!).inHours > 6) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showModernNotification(
                "$name: Only $daysRemaining day(s) left until hatching!",
                color: Colors.amber,
                icon: Icons.egg,
              );
            });
            _lastHatchNotification = now;
          }
        }
      }
    }
    int normal = 0;
    int warnings = 0;
    normalIncubators.clear();
    warningIncubators.clear();
    warningDetails.clear();

    _currentIncubatorData.forEach((name, values) {
      List<String> issues = [];

      if (values['humidity'] < 35 || values['humidity'] > 65) {
        issues.add("Humidity out of range");
      }
      if (values['temperature'] < 36 || values['temperature'] > 39) {
        issues.add("Temperature out of range");
      }
      if (values['oxygen'] < 19) {
        issues.add("Low oxygen level");
      }
      if (values['co2'] > 900) { 
        issues.add("High CO₂ level");
      }

      if (issues.isEmpty) {
        normal++;
        normalIncubators.add(name);
      } else {
        warnings++;
        warningIncubators.add(name);
        warningDetails[name] = issues;
      }
    });

    if (mounted) {
      setState(() {
        normalCount = normal;
        warningCount = warnings;
      });
      // Throttle warning notifications to avoid spamming
      if (warningCount > 0) {
        final now = DateTime.now();
        if (_lastWarningNotification == null || now.difference(_lastWarningNotification!).inSeconds > 15) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showModernNotification(
              "$warningCount incubator(s) need attention!",
              color: Colors.redAccent,
              icon: Icons.warning,
            );
          });
          _lastWarningNotification = now;
        }
      }
    }
  }


  String _getBatchSummary(String incubatorName) {
    final data = _currentIncubatorData[incubatorName];
    if (data == null) return 'No batch info';
    
    final String batchName = data['batchName'] ?? 'No batch';
    return batchName;
  }

  String _getDaysRemaining(String incubatorName) {
    final data = _currentIncubatorData[incubatorName];
    if (data == null) return '';
    
    final int startDateMs = data['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
    final int incubationDays = data['incubationDays'] ?? 21;
    
    final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
    final DateTime now = DateTime.now();
    final Duration elapsed = now.difference(startDate);
    final int daysElapsed = elapsed.inDays;
    final int daysRemaining = (incubationDays - daysElapsed).clamp(0, incubationDays);
    
    if (daysRemaining == 0) {
      return 'Ready to hatch!';
    } else if (daysRemaining == 1) {
      return '1 day left';
    } else {
      return '$daysRemaining days left';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Overview"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => DraggableScrollableSheet(
                  initialChildSize: 0.9,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (context, scrollController) => Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: ProfileScreen(
                      incubatorData: incubatorData,
                      selectedIncubator:
                          incubators.isNotEmpty ? incubators.first : '',
                      themeNotifier: widget.themeNotifier,
                      userName: userName,
                      onUserNameChanged: () async {
                        // Refresh user data from Firebase
                        final userData = await AuthService.getUserData();
                        if (mounted && userData != null) {
                          setState(() {
                            userName = userData['username'] ?? userName;
                          });
                          widget.onUserNameChanged?.call(userName);
                        }
                      },
                    ),
                  ),
                ),
              );

              if (mounted) {
                setState(() {
                  incubators = List<String>.from(incubatorData.keys);
                  _updateCounts();
                });
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            isNewUser ? "Welcome, $userName!" : "Welcome back, $userName!",
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          _buildAnalyticsSummaryCard(isDarkMode),
          const SizedBox(height: 20),

          Text(
            "System Overview",
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          if (normalIncubators.isNotEmpty) ...[
            Card(
              color: isDarkMode ? const Color(0xFF1B4332) : Colors.green.shade100,
              elevation: 2,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified,
                          color: isDarkMode ? const Color(0xFF40C057) : Colors.green.shade700,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Stable Incubators",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDarkMode ? const Color(0xFF40C057) : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "$normalCount incubator(s) operating within optimal parameters",
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    ...normalIncubators.asMap().entries.map((entry) {
                      final index = entry.key;
                      final name = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300 + (index * 100)),
                          curve: Curves.easeOutBack,
                          child: GestureDetector(
                            onTap: () {
                              if (widget.onNavigateToDashboard != null) {
                                widget.onNavigateToDashboard!(name);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: isDarkMode ? const Color(0xFF1B4332) : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDarkMode ? const Color(0xFF40C057) : Colors.green.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: isDarkMode ? const Color(0xFF40C057) : Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode ? const Color(0xFF40C057) : Colors.green.shade700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          _getBatchSummary(name),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDarkMode ? const Color(0xFF51CF66) : Colors.green.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "All systems normal",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDarkMode ? const Color(0xFF51CF66) : Colors.green.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      Text(
                                        _getDaysRemaining(name),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDarkMode ? const Color(0xFF69DB7C) : Colors.green.shade500,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: isDarkMode ? const Color(0xFF69DB7C) : Colors.green.shade400,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],

          if (warningIncubators.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 6),
                Text(
                  "Warnings",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...warningIncubators.map((incubator) => GestureDetector(
                  onTap: () {
                    if (widget.onNavigateToDashboard != null) {
                      widget.onNavigateToDashboard!(incubator);
                    }
                  },
                  child: Card(
                    color: isDarkMode ? const Color(0xFF2D1B0F) : Colors.orange.shade100,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          incubator,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Text(
                                        _getDaysRemaining(incubator),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDarkMode ? const Color(0xFFFF8C42) : Colors.orange.shade600,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _getBatchSummary(incubator),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDarkMode ? const Color(0xFFFFB347) : Colors.orange.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...warningDetails[incubator]!.map((issue) =>
                                      Text("- $issue",
                                          style: const TextStyle(fontSize: 13))),
                                ]),
                          ),
                          Column(
                            children: [
                              Icon(Icons.error, color: isDarkMode ? const Color(0xFFFF5252) : Colors.red),
                              const SizedBox(height: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: isDarkMode ? const Color(0xFFFF8C42) : Colors.orange.shade400,
                                size: 16,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          ],

          // --- Maintenance Section ---
          const SizedBox(height: 20),
GestureDetector(
  onTap: () {
    widget.onNavigateToMaintenance?.call();
  },
  child: Card(
    elevation: 2,
    color: isDarkMode ? const Color(0xFF0F1B2D) : const Color(0xFFE3F2FD),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.build_circle_rounded, color: Colors.blueAccent, size: 28),
              SizedBox(width: 10),
              Text(
                "Maintenance",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          FutureBuilder<Map<String, dynamic>>(
            future: FirebaseDatabase.instance
                .ref("HatchTech/Maintenance")
                .get()
                .then((snapshot) => (snapshot.value ?? {}) as Map<String, dynamic>),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text(
                  "No recent maintenance records found.",
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                );
              }

              final maintenanceRecords = snapshot.data!;
              final entries = maintenanceRecords.entries.toList()
                ..sort((a, b) => b.value['timestamp'].compareTo(a.value['timestamp']));

              final latestRecords = entries.take(3).toList();

              return Column(
                children: latestRecords.map((entry) {
                  final data = entry.value;
                  final date = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
                  final formattedDate =
                      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

                  return Card(
                    color: isDarkMode ? const Color(0xFF0F1B2D) : Colors.blue.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: const Icon(Icons.settings, color: Colors.blueAccent),
                      title: Text(
                        data['task'] ?? 'Maintenance Task',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Date: $formattedDate\nBy: ${data['performedBy'] ?? 'N/A'}"),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ),
  ),
),


          if (normalIncubators.isEmpty && warningIncubators.isEmpty) ...[
            const SizedBox(height: 20),
            Card(
              color: isDarkMode ? const Color(0xFF0F1B2D) : Colors.blue.shade50,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.sensors,
                      color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue.shade600,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "System Monitoring",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "All incubators are being monitored. Status updates will appear here when conditions change.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? const Color(0xFF9FC5FF) : Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyticsSummaryCard(bool isDarkMode) {
    final dataSource = widget.sharedIncubatorData ?? incubatorData;
    final batchHistoryData = (widget.batchHistory != null && widget.batchHistory!.isNotEmpty)
        ? widget.batchHistory!
        : _localBatchHistory;
    // import helper
    // avoid unused import lint by referencing the helper methods below
    // (actual import added at top of file)
    
    final double rateValue = calculateOverallHatchRate(batchHistoryData);
    final String hatchRate = rateValue > 0 ? '${rateValue.toStringAsFixed(1)}%' : 'N/A';
    // Candling notification logic
    final now = DateTime.now();
    dataSource.forEach((name, data) {
      final int startDateMs = data['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
      final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
  // Removed unused daysElapsed variable
      bool isCompleted = false;
      if (batchHistoryData.isNotEmpty) {
        final batchName = data['batchName'] ?? '';
        isCompleted = batchHistoryData.any((batch) => 
          batch['batchName'] == batchName && batch['reason'] != null);
      }
      if (!isCompleted) {
        for (int day in [7, 14, 18]) {
          final DateTime candlingDate = startDate.add(Duration(days: day));
          final int daysToCandling = candlingDate.difference(now).inDays;
          if (daysToCandling <= 2 && daysToCandling >= 0) {
            final lastNotify = _lastCandlingNotification['${name}_$day'];
            if (lastNotify == null || now.difference(lastNotify).inHours > 6) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showModernNotification(
                  "$name: Candling scheduled in $daysToCandling day(s) (Day $day)",
                  color: Colors.lightBlue,
                  icon: Icons.lightbulb,
                );
              });
              _lastCandlingNotification['${name}_$day'] = now;
            }
            break;
          }
        }
      }
    });
    
    // Use shared helper to determine next candling date
    String nextCandlingDate = getNextCandlingDate(dataSource, batchHistoryData);

    return Card(
      color: isDarkMode ? const Color(0xFF0F1B2D) : Colors.blue.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Analytics Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickStat(
                    'Hatch Rate',
                    hatchRate,
                    Icons.trending_up,
                    Colors.green,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickStat(
                    'Active Batches',
                    '${dataSource.length}',
                    Icons.egg,
                    Colors.orange,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickStat(
                    'Next Candling',
                    nextCandlingDate == 'No active batches' ? 'N/A' : nextCandlingDate,
                    Icons.visibility,
                    Colors.purple,
                    isDarkMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onNavigateToAnalytics?.call();
                },
                icon: const Icon(Icons.analytics, size: 18),
                label: const Text('View Detailed Analytics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color, bool isDarkMode) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget buildMaintenanceSection() {
    return StreamBuilder(
      stream: FirebaseDatabase.instance
          .ref("HatchTech/$selectedIncubator/maintenance/active")
          .onValue,
      builder: (context, snapshot) {
        final rawValue = snapshot.data!.snapshot.value;
        if (rawValue is Map) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(rawValue);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("⚙️ Predictive Maintenance Alerts",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...data.entries.map((entry) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    title: Text(entry.key.toUpperCase()),
                    subtitle: Text(entry.value.toString()),
                  ),
                )),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton( 
                    onPressed: () { 
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MaintenanceLogPage(incubatorId: selectedIncubator, userName: currentUserName, themeNotifier: widget.themeNotifier,),
                        ),
                      );
                    },
                    child: const Text("View All →"),
                  ),
                ),
             ],
            );
          } else {
            return const Text("No current maintenance alerts ✅");
          }
          },
    );
  }

}