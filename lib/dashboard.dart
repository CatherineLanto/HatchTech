import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'profile_screen.dart';
import 'services/auth_service.dart';

class Dashboard extends StatefulWidget {
  final String incubatorName;
  final String userName;
  final ValueNotifier<ThemeMode> themeNotifier;
  final Map<String, Map<String, dynamic>>? incubatorData;
  final Map<String, Map<String, dynamic>>? scheduledCandlingData;
  final Function(Map<String, Map<String, dynamic>>)? onDataChanged;
  final Function(String)? onUserNameChanged;
  final Function(Map<String, Map<String, dynamic>>)? onScheduleChanged;
  final Function(List<Map<String, dynamic>>)? onBatchHistoryChanged;
  
  const Dashboard({
    super.key, 
    required this.incubatorName, 
    required this.userName, 
    required this.themeNotifier,
    this.incubatorData,
    this.scheduledCandlingData,
    this.onDataChanged,
    this.onUserNameChanged,
    this.onScheduleChanged,
    this.onBatchHistoryChanged,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  String selectedIncubator = 'Incubator 1';
  bool showWarning = false;
  List<Map<String, dynamic>> currentAlerts = [];
  Timer? dataUpdateTimer;
  Timer? _autoDismissTimer;
  DateTime? lastAlertTime;
  final Duration alertCooldown = const Duration(seconds: 20);
  bool isDropdownOpen = false;
  FocusNode dropdownFocusNode = FocusNode();
  late String currentUserName;
  late AnimationController _warningAnimationController;
  late Animation<double> _warningAnimation;

  final Map<String, Map<String, dynamic>> incubatorData = {};
  List<Map<String, dynamic>> batchHistory = []; 

  @override
  void initState() {
    super.initState();
    
    currentUserName = widget.userName;
    
    _warningAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _warningAnimation = CurvedAnimation(
      parent: _warningAnimationController,
      curve: Curves.elasticOut,
    );
    
    if (widget.incubatorData != null && widget.incubatorData!.isNotEmpty) {
      incubatorData.addAll(widget.incubatorData!);
    } else {
      final now = DateTime.now();
      incubatorData.addAll({
        'Incubator 1': {
          'temperature': 37.5, 
          'humidity': 50.0, 
          'oxygen': 20.5, 
          'co2': 800.0, 
          'eggTurning': true, 
          'lighting': true,
          'batchName': 'Batch A-001',
          'startDate': now.subtract(const Duration(days: 12)).millisecondsSinceEpoch,
          'incubationDays': 21,
          'eggCount': 24,
          'eggBreed': 'Rhode Island Red',
          'candlingDates': {
            '7': false,  
            '14': false, 
            '18': false, 
          },
          'fertilityRate': null,
          'viableEggs': 24,
          'hatchedCount': null,
        },
        'Incubator 2': {
          'temperature': 37.8, 
          'humidity': 55.0, 
          'oxygen': 20.0, 
          'co2': 750.0, 
          'eggTurning': false, 
          'lighting': false,
          'batchName': 'Batch B-002',
          'startDate': now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
          'incubationDays': 21,
          'eggCount': 18,
          'eggBreed': 'Leghorn',
          'candlingDates': {
            '7': true,  
            '14': false, 
            '18': false, 
          },
          'fertilityRate': 85.0,
          'viableEggs': 15, 
          'hatchedCount': null,
        },
      });
    }
    
  selectedIncubator = widget.incubatorName;
  // Listen to Firebase Realtime Database for sensor data
  listenToSensorData();
  }

  // Removed updateSensorData: now handled by Firebase listener
  void listenToSensorData() {
    final dbRef = FirebaseDatabase.instance.ref('HatchTech/Incubator1');
    dbRef.onValue.listen(
      (event) {
        try {
          final data = event.snapshot.value as Map?;
          print('Received sensor data: $data'); // Debug print
          if (data != null) {
            setState(() {
              incubatorData['Incubator 1'] = Map<String, dynamic>.from({
                ...incubatorData['Incubator 1'] ?? {},
                ...data,
                'temperature': (data['temperature'] is num)
                    ? (data['temperature'] as num).toDouble()
                    : (incubatorData['Incubator 1']?['temperature'] ?? 0.0),
                'humidity': (data['humidity'] is num)
                    ? (data['humidity'] as num).toDouble()
                    : (incubatorData['Incubator 1']?['humidity'] ?? 0.0),
                'oxygen': (data['oxygen'] is num)
                    ? (data['oxygen'] as num).toDouble()
                    : (incubatorData['Incubator 1']?['oxygen'] ?? 0.0),
                'co2': (data['co2'] is num)
                    ? (data['co2'] as num).toDouble()
                    : (incubatorData['Incubator 1']?['co2'] ?? 0.0),
              });
            });
            checkAlerts();
            _notifyDataChanged();
          }
        } catch (e, stack) {
          print('Error in sensor listener: $e\n$stack');
        }
      },
      onError: (error) {
        print('Firebase listener error: $error');
      },
    );
  }

  // Removed unused _clampValue method

  void checkAlerts() {
    final now = DateTime.now();
    if (lastAlertTime != null && now.difference(lastAlertTime!) < alertCooldown) return;

    List<Map<String, dynamic>> alerts = [];

    incubatorData.forEach((key, values) {
      if (key == selectedIncubator) return; 
      
      if (values['temperature'] < 36 || values['temperature'] > 39) {
        alerts.add({
          'incubator': key,
          'type': 'Temperature',
          'message': 'Temperature out of range (${values['temperature'].toStringAsFixed(1)}°C)',
          'severity': 'critical',
          'value': values['temperature'],
          'unit': '°C',
          'icon': Icons.thermostat,
        });
      }
      if (values['oxygen'] < 19) {
        alerts.add({
          'incubator': key,
          'type': 'Oxygen',
          'message': 'Low Oxygen (${values['oxygen'].toStringAsFixed(1)}%)',
          'severity': 'critical',
          'value': values['oxygen'],
          'unit': '%',
          'icon': Icons.air,
        });
      }
      
      if (values['humidity'] < 35 || values['humidity'] > 65) {
        alerts.add({
          'incubator': key,
          'type': 'Humidity',
          'message': 'Humidity out of range (${values['humidity'].toStringAsFixed(1)}%)',
          'severity': 'warning',
          'value': values['humidity'],
          'unit': '%',
          'icon': Icons.water_drop,
        });
      }
      if (values['co2'] > 900) {
        alerts.add({
          'incubator': key,
          'type': 'CO₂',
          'message': 'High CO₂ (${values['co2'].toStringAsFixed(0)} ppm)',
          'severity': 'warning',
          'value': values['co2'],
          'unit': ' ppm',
          'icon': Icons.cloud,
        });
      }
    });

    if (alerts.isNotEmpty) {
      setState(() {
        currentAlerts = alerts;
        showWarning = true;
        lastAlertTime = now;
      });
      _warningAnimationController.forward();
      
      final hasCriticalAlert = alerts.any((alert) => alert['severity'] == 'critical');
      if (!hasCriticalAlert) {
        _autoDismissTimer?.cancel();
        _autoDismissTimer = Timer(const Duration(seconds: 15), () {
          if (mounted && showWarning) {
            _dismissWarning();
          }
        });
      }
    } else if (showWarning) {
      _dismissWarning();
    }
  }

  void _dismissWarning() {
    _autoDismissTimer?.cancel();
    _warningAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          showWarning = false;
          currentAlerts.clear();
        });
      }
    });
  }

  void _notifyDataChanged() {
    if (widget.onDataChanged != null) {
      widget.onDataChanged!(Map.from(incubatorData));
    }
  }

  // Batch History Management Methods
  // Removed unused _loadBatchHistory method

  Future<void> _saveBatchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = jsonEncode(batchHistory);
      await prefs.setString('batch_history', historyJson);
      
      if (widget.onBatchHistoryChanged != null) {
        widget.onBatchHistoryChanged!(List.from(batchHistory));
      }
    } catch (e) {
      debugPrint('Error saving batch history: $e');
    }
  }

  void _addBatchToHistory(Map<String, dynamic> batchData, String incubatorName, {String reason = 'Completed'}) {
    final historyEntry = Map<String, dynamic>.from(batchData);
    historyEntry['incubatorName'] = incubatorName;
    historyEntry['completedDate'] = DateTime.now().millisecondsSinceEpoch;
    historyEntry['completionReason'] = reason; 
    
    setState(() {
      batchHistory.insert(0, historyEntry); 
    });
    _saveBatchHistory();
  }

  void addNewIncubator() {
    int count = incubatorData.length + 1;
    String newName = 'Incubator $count';
    final now = DateTime.now();
    incubatorData[newName] = {
      'temperature': 36.5 + Random().nextDouble() * 2,
      'humidity': 40 + Random().nextDouble() * 25,
      'oxygen': 18.0 + Random().nextDouble() * 3,
      'co2': 700 + Random().nextDouble() * 400,
      'eggTurning': Random().nextBool(),
      'lighting': Random().nextBool(),
      'batchName': 'Batch ${String.fromCharCode(65 + count - 1)}-${count.toString().padLeft(3, '0')}',
      'startDate': now.millisecondsSinceEpoch,
      'incubationDays': 21,
      'eggCount': 12,
      'eggBreed': 'Mixed',
      'candlingDates': {
        '7': false,
        '14': false,
        '18': false,
      },
      'fertilityRate': null,
      'viableEggs': 12,
      'hatchedCount': null,
    };
    setState(() {
      selectedIncubator = newName;
    });
    checkAlerts();
    _notifyDataChanged();
  }

  void showRenameDialog(BuildContext context, String incubatorKey) {
  final TextEditingController controller = TextEditingController(text: incubatorKey);
  final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : null,
      title: Text(
        'Rename Incubator',
        style: TextStyle(
          color: isDarkMode ? Colors.white : null,
        ),
      ),
      content: TextField(
        controller: controller,
        style: TextStyle(
          color: isDarkMode ? Colors.white : null,
        ),
        decoration: InputDecoration(
          labelText: 'New Incubator Name',
          labelStyle: TextStyle(
            color: isDarkMode ? const Color(0xFFB0B0B0) : null,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            String newName = controller.text.trim();
            if (newName.isNotEmpty && !incubatorData.containsKey(newName)) {
              setState(() {
                incubatorData[newName] = incubatorData.remove(incubatorKey)!;
                if (selectedIncubator == incubatorKey) {
                  selectedIncubator = newName;
                }
              });
              _notifyDataChanged();
              Navigator.pop(context);
            }
          },
          child: const Text('Rename'),
        ),
      ],
    ),
  );
  }

  @override
  void dispose() {
  dropdownFocusNode.dispose();
  dataUpdateTimer?.cancel();
  _autoDismissTimer?.cancel();
  _warningAnimationController.dispose();
  print('Dashboard disposed, cleaning up listeners.');
  super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!incubatorData.containsKey(selectedIncubator)) {
      if (incubatorData.isNotEmpty) {
        selectedIncubator = incubatorData.keys.first;
      } else {
        return Scaffold(
          appBar: AppBar(title: const Text('Dashboard')),
          body: const Center(child: Text('No incubators available')),
        );
      }
    }

  // Always get the latest data for the selected incubator
  final selected = incubatorData[selectedIncubator]!;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _notifyDataChanged();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
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
                      selectedIncubator: selectedIncubator,
                      themeNotifier: widget.themeNotifier,
                      userName: currentUserName,
                      onUserNameChanged: () async {
                        // Refresh username from Firebase
                        final user = AuthService.currentUser;
                        if (user != null) {
                          final newUserName = user.displayName ?? 'User';
                          setState(() {
                            currentUserName = newUserName;
                          });
                          widget.onUserNameChanged?.call(newUserName);
                        }
                      },
                    ),
                  ),
                ),
              );

              setState(() {
                if (!incubatorData.containsKey(selectedIncubator)) {
                  selectedIncubator = incubatorData.keys.first;
                }
                checkAlerts();
              });
              
              if (widget.onDataChanged != null) {
                widget.onDataChanged!(Map.from(incubatorData));
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Focus(
                        focusNode: dropdownFocusNode,
                        onFocusChange: (hasFocus) {
                          setState(() {
                            isDropdownOpen = hasFocus;
                          });
                        },
                        child: DropdownButtonFormField<String>(
                          value: selectedIncubator,
                          items: incubatorData.keys.map((key) {
                            return DropdownMenuItem(
                              value: key,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(key),
                                  if (isDropdownOpen)
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        showRenameDialog(context, key);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          selectedItemBuilder: (context) {
                            return incubatorData.keys.map((key) => Text(key)).toList();
                          },
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedIncubator = value;
                                showWarning = false;
                                checkAlerts();
                              });
                            }
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: addNewIncubator,
                      icon: const Icon(Icons.add),
                      label: const Text("Add"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 8,
                          children: [
                            buildSensorCard('Temperature', selected['temperature'], Icons.thermostat, max: 40),
                            buildSensorCard('Humidity', selected['humidity'], Icons.water_drop, max: 100),
                            buildSensorCard('Oxygen', selected['oxygen'], Icons.air, max: 25),
                            buildSensorCard('CO₂', selected['co2'], Icons.cloud, max: 1200),
                            buildToggleCard('Egg Turning', selected['eggTurning'], (val) {
                              setState(() {
                                incubatorData[selectedIncubator]!['eggTurning'] = val;
                              });
                            }),
                            buildToggleCard('Lighting', selected['lighting'], (val) {
                              setState(() {
                                incubatorData[selectedIncubator]!['lighting'] = val;
                              });
                            }),
                          ],
                        ),
                        const SizedBox(height: 2), 
                        buildBatchTrackingCard(selected),
                        const SizedBox(height: 12),
                        // Start New Batch Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => showStartNewBatchDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Start New Batch'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16), 
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showWarning) 
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: buildWarningDialog(),
            ),
        ],
      ),
    )
    );
  }

  Widget buildSensorCard(String label, double value, IconData icon, {double max = 100}) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    double percentage = value / max;
    Color barColor = (label == 'Humidity' && (value < 35 || value > 65)) ||
            (label == 'Temperature' && (value < 36 || value > 39)) ||
            (label == 'Oxygen' && value < 19.0) ||
            (label == 'CO₂' && value > 900)
        ? (isDarkMode ? const Color(0xFFFF5252) : Colors.red)
        : (isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
          )
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<Color?>(
            duration: const Duration(milliseconds: 500),
            tween: ColorTween(begin: Colors.grey, end: barColor),
            builder: (context, color, child) {
              return Icon(icon, size: 40, color: color);
            },
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: percentage.clamp(0.0, 1.0)),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, child) {
              return CircularProgressIndicator(
                value: animatedValue,
                color: barColor,
                strokeWidth: 6,
              );
            },
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 600),
            tween: Tween(begin: 0.0, end: value),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, child) {
              return Text(
                animatedValue.toStringAsFixed(1),
                style: Theme.of(context).textTheme.titleLarge,
              );
            },
          ),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: barColor.withValues(alpha: 0.8),
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  Widget buildToggleCard(String label, bool isOn, Function(bool) onChanged) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    IconData icon = label == 'Lighting' ? Icons.lightbulb : Icons.sync;
    Color iconColor = isOn 
        ? (isDarkMode ? const Color(0xFF40C057) : Colors.green) 
        : (isDarkMode ? const Color(0xFF6C757D) : Colors.grey);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
           color: isDarkMode ? Colors.black26 : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<Color?>(
            duration: const Duration(milliseconds: 400),
            tween: ColorTween(begin: Colors.grey, end: iconColor),
            builder: (context, color, child) {
              if (label == 'Egg Turning') {
                return AnimatedRotation(
                  duration: const Duration(milliseconds: 300),
                  turns: isOn ? 0.0 : 0.25,
                  child: Icon(icon, size: 40, color: color),
                );
              } else {
                return Icon(icon, size: 40, color: color);
              }
            },
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Switch(
              key: ValueKey(isOn),
              value: isOn,
              onChanged: onChanged,
              activeColor: isDarkMode ? const Color(0xFF40C057) : Colors.green,
            ),
          ),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: iconColor.withValues(alpha: 0.8),
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  Widget buildBatchTrackingCard(Map<String, dynamic> data) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Get batch info with default values if not present
    final String batchName = data['batchName'] ?? 'No batch';
    final int startDateMs = data['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
    final int incubationDays = data['incubationDays'] ?? 21;
    
    final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
    final DateTime now = DateTime.now();
    final Duration elapsed = now.difference(startDate);
    final int daysElapsed = elapsed.inDays;
    final int daysRemaining = (incubationDays - daysElapsed).clamp(0, incubationDays);
    final double progress = (daysElapsed / incubationDays).clamp(0.0, 1.0);
    
    Color progressColor;
    IconData batchIcon;
    String statusText;
    
    if (daysRemaining == 0) {
      progressColor = isDarkMode ? const Color(0xFF40C057) : Colors.green;
      batchIcon = Icons.celebration;
      statusText = 'Ready to hatch!';
    } else if (daysRemaining <= 3) {
      progressColor = isDarkMode ? const Color(0xFFFFB347) : Colors.orange;
      batchIcon = Icons.schedule;
      statusText = 'Hatching soon';
    } else {
      progressColor = isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue;
      batchIcon = Icons.egg;
      statusText = 'Incubating';
    }

    return GestureDetector(
      onTap: () => showBatchDialog(context, data),
      child: AnimatedContainer(
        height: 85,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black26 : Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Icon
            TweenAnimationBuilder<Color?>(
              duration: const Duration(milliseconds: 500),
              tween: ColorTween(begin: Colors.grey, end: progressColor),
              builder: (context, color, child) {
                return Icon(batchIcon, size: 36, color: color);
              },
            ),
            const SizedBox(width: 16),
            // Batch Information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          batchName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: progressColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: progressColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Day $daysElapsed/$incubationDays',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Linear Progress Bar
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0.0, end: progress),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedValue, child) {
                      return LinearProgressIndicator(
                        value: animatedValue,
                        backgroundColor: isDarkMode 
                            ? const Color(0xFF333333) 
                            : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 6,
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: progressColor.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text(
                        daysRemaining == 0 ? 'Ready to hatch!' : 
                        daysRemaining == 1 ? '1 day left' : '$daysRemaining days left',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void showBatchDialog(BuildContext context, Map<String, dynamic> data) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String batchName = data['batchName'] ?? 'No batch';
    final int startDateMs = data['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
    final int incubationDays = data['incubationDays'] ?? 21;
    
    final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
    final DateTime expectedHatchDate = startDate.add(Duration(days: incubationDays));
    final DateTime now = DateTime.now();
    final Duration elapsed = now.difference(startDate);
    final int daysElapsed = elapsed.inDays;
    final int hoursElapsed = elapsed.inHours % 24;
    final int daysRemaining = (incubationDays - daysElapsed).clamp(0, incubationDays);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : null,
        title: Row(
          children: [
            Icon(Icons.egg, color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Batch Details',
                style: TextStyle(color: isDarkMode ? Colors.white : null),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Batch Name:', batchName, isDarkMode),
            const SizedBox(height: 8),
            _buildDetailRow('Egg Count:', '${data['eggCount'] ?? 0} eggs', isDarkMode),
            const SizedBox(height: 8),
            _buildDetailRow('Egg Breed:', data['eggBreed'] ?? 'Unknown', isDarkMode),
            const SizedBox(height: 8),
            _buildDetailRow('Started:', 
              '${startDate.day}/${startDate.month}/${startDate.year}', isDarkMode),
            const SizedBox(height: 8),
            _buildDetailRow('Expected Hatch:', 
              '${expectedHatchDate.day}/${expectedHatchDate.month}/${expectedHatchDate.year}', isDarkMode),
            const SizedBox(height: 8),
            _buildDetailRow('Time Elapsed:', 
              '$daysElapsed days, $hoursElapsed hours', isDarkMode),
            const SizedBox(height: 8),
            _buildDetailRow('Days Remaining:', 
              daysRemaining == 0 ? 'Ready to hatch!' : 
              daysRemaining == 1 ? '1 day left' : '$daysRemaining days left', isDarkMode),
            const SizedBox(height: 8),
            _buildDetailRow('Incubation Period:', '$incubationDays days', isDarkMode),
            const SizedBox(height: 16),
            // Candling Section
            Text(
              'Candling Progress',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildCandlingRowWithScheduled('Day 7:', data['candlingDates']['7'] ?? false, isDarkMode, 7, selectedIncubator),
            const SizedBox(height: 4),
            _buildCandlingRowWithScheduled('Day 14:', data['candlingDates']['14'] ?? false, isDarkMode, 14, selectedIncubator),
            const SizedBox(height: 4),
            _buildCandlingRowWithScheduled('Day 18:', data['candlingDates']['18'] ?? false, isDarkMode, 18, selectedIncubator),
            const SizedBox(height: 8),
            if (data['fertilityRate'] != null)
              _buildDetailRow('Fertility Rate:', '${data['fertilityRate'].toStringAsFixed(1)}%', isDarkMode),
            if (data['fertilityRate'] != null)
              const SizedBox(height: 8),
            _buildDetailRow('Viable Eggs:', '${data['viableEggs'] ?? data['eggCount'] ?? 0}', isDarkMode),
            const SizedBox(height: 8),
            if (data['hatchedCount'] != null) ...[
              _buildDetailRow('Hatched:', '${data['hatchedCount']}', isDarkMode),
              const SizedBox(height: 8),
              _buildDetailRow('Hatch Success Rate:', 
                '${((data['hatchedCount'] / (data['eggCount'] ?? 1)) * 100).toStringAsFixed(1)}%', isDarkMode),
              const SizedBox(height: 8),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (daysRemaining == 0 && data['hatchedCount'] == null)
            TextButton(
              onPressed: () => showHatchResultDialog(context, data),
              child: const Text('Record Hatch'),
            ),
          ElevatedButton(
            onPressed: () => showEditBatchDialog(context, data),
            child: const Text('Edit Batch'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  void showEditBatchDialog(BuildContext context, Map<String, dynamic> data) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController batchController = TextEditingController(text: data['batchName'] ?? '');
    final TextEditingController daysController = TextEditingController(text: (data['incubationDays'] ?? 21).toString());
    final TextEditingController eggCountController = TextEditingController(text: (data['eggCount'] ?? 0).toString());
    final TextEditingController breedController = TextEditingController(text: data['eggBreed'] ?? '');
    
    Navigator.pop(context); 
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : null,
        title: Text(
          'Edit Batch Information',
          style: TextStyle(color: isDarkMode ? Colors.white : null),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: batchController,
                style: TextStyle(color: isDarkMode ? Colors.white : null),
                decoration: InputDecoration(
                  labelText: 'Batch Name',
                  labelStyle: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : null),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: eggCountController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDarkMode ? Colors.white : null),
                decoration: InputDecoration(
                  labelText: 'Number of Eggs',
                  labelStyle: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : null),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: breedController,
                style: TextStyle(color: isDarkMode ? Colors.white : null),
                decoration: InputDecoration(
                  labelText: 'Egg Breed/Type',
                  labelStyle: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : null),
                  hintText: 'e.g., Rhode Island Red, Leghorn',
                  hintStyle: TextStyle(color: isDarkMode ? const Color(0xFF666666) : null),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDarkMode ? Colors.white : null),
                decoration: InputDecoration(
                  labelText: 'Incubation Days',
                  labelStyle: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : null),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              showBatchDialog(context, incubatorData[selectedIncubator]!);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final String newBatchName = batchController.text.trim();
              final int newDays = int.tryParse(daysController.text) ?? 21;
              final int newEggCount = int.tryParse(eggCountController.text) ?? 0;
              final String newBreed = breedController.text.trim();
              
              if (newBatchName.isNotEmpty && newDays > 0 && newEggCount >= 0) {
                setState(() {
                  incubatorData[selectedIncubator]!['batchName'] = newBatchName;
                  incubatorData[selectedIncubator]!['incubationDays'] = newDays;
                  incubatorData[selectedIncubator]!['eggCount'] = newEggCount;
                  incubatorData[selectedIncubator]!['eggBreed'] = newBreed.isEmpty ? 'Unknown' : newBreed;
                });
                _notifyDataChanged();
                Navigator.pop(context); 
                showBatchDialog(context, incubatorData[selectedIncubator]!);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void showStartNewBatchDialog(BuildContext context) {
    final currentBatch = incubatorData[selectedIncubator];
    final bool hasActiveBatch = currentBatch != null && 
        currentBatch['batchName'] != null && 
        currentBatch['batchName'].toString().isNotEmpty;

    if (hasActiveBatch) {
      showActiveBatchWarningDialog(context);
    } else {
      showNewBatchFormDialog(context);
    }
  }

  void showActiveBatchWarningDialog(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentBatch = incubatorData[selectedIncubator]!;
    final String currentBatchName = currentBatch['batchName'] ?? 'Unknown Batch';
    final int startDateMs = currentBatch['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
    final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
    final int daysElapsed = DateTime.now().difference(startDate).inDays;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : null,
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Replace Active Batch?',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You currently have an active batch in progress:',
              style: TextStyle(
                color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode ? const Color(0xFF444444) : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📦 $currentBatchName',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🥚 ${currentBatch['eggCount']} ${currentBatch['eggBreed'] ?? 'Unknown'} eggs',
                    style: TextStyle(
                      color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '📅 Day $daysElapsed of ${currentBatch['incubationDays'] ?? 21}',
                    style: TextStyle(
                      color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2A1F1F) : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Starting a new batch will save your current batch to history and replace it.',
                      style: TextStyle(
                        color: isDarkMode ? Colors.orange.shade200 : Colors.orange.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _addBatchToHistory(currentBatch, selectedIncubator, reason: 'Replaced');
              Navigator.pop(context);
              showNewBatchFormDialog(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Replace & Continue'),
          ),
        ],
      ),
    );
  }

  void showNewBatchFormDialog(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController batchController = TextEditingController();
    final TextEditingController eggCountController = TextEditingController(text: '12');
    final TextEditingController breedController = TextEditingController();
    final TextEditingController daysController = TextEditingController(text: '21');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : null,
        title: Row(
          children: [
            Icon(
              Icons.add_circle,
              color: isDarkMode ? const Color(0xFF4CAF50) : Colors.green,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Start New Batch',
              style: TextStyle(color: isDarkMode ? Colors.white : null),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: batchController,
                style: TextStyle(color: isDarkMode ? Colors.white : null),
                decoration: InputDecoration(
                  labelText: 'Batch Name *',
                  labelStyle: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : null),
                  hintText: 'e.g., Spring Batch 2024',
                  hintStyle: TextStyle(color: isDarkMode ? const Color(0xFF666666) : null),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: eggCountController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDarkMode ? Colors.white : null),
                decoration: InputDecoration(
                  labelText: 'Number of Eggs *',
                  labelStyle: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : null),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: breedController,
                style: TextStyle(color: isDarkMode ? Colors.white : null),
                decoration: InputDecoration(
                  labelText: 'Egg Breed/Type',
                  labelStyle: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : null),
                  hintText: 'e.g., Rhode Island Red',
                  hintStyle: TextStyle(color: isDarkMode ? const Color(0xFF666666) : null),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDarkMode ? Colors.white : null),
                decoration: InputDecoration(
                  labelText: 'Incubation Days',
                  labelStyle: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : null),
                  hintText: '21 for chickens, 28 for ducks',
                  hintStyle: TextStyle(color: isDarkMode ? const Color(0xFF666666) : null),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final String batchName = batchController.text.trim();
              final int eggCount = int.tryParse(eggCountController.text) ?? 0;
              final String breed = breedController.text.trim();
              final int days = int.tryParse(daysController.text) ?? 21;
              
              if (batchName.isNotEmpty && eggCount > 0) {
                setState(() {
                  incubatorData[selectedIncubator]!['batchName'] = batchName;
                  incubatorData[selectedIncubator]!['eggCount'] = eggCount;
                  incubatorData[selectedIncubator]!['eggBreed'] = breed.isEmpty ? 'Mixed' : breed;
                  incubatorData[selectedIncubator]!['incubationDays'] = days;
                  incubatorData[selectedIncubator]!['startDate'] = DateTime.now().millisecondsSinceEpoch;
                  incubatorData[selectedIncubator]!['viableEggs'] = eggCount; // Start with all eggs viable
                  incubatorData[selectedIncubator]!['candlingDates'] = {
                    '7': false,
                    '14': false,
                    '18': false,
                  };
                  incubatorData[selectedIncubator]!['fertilityRate'] = null;
                  incubatorData[selectedIncubator]!['hatchedCount'] = null;
                });
                _notifyDataChanged();
                Navigator.pop(context);
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('New batch "$batchName" started successfully!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Batch'),
          ),
        ],
      ),
    );
  }

  Widget buildWarningDialog() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _warningAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _warningAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            constraints: const BoxConstraints(maxHeight: 400),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDarkMode 
                        ? [
                            const Color(0xFF2D1B1B),
                            const Color(0xFF2D1B0F),
                          ]
                        : [
                            Colors.red.shade50,
                            Colors.orange.shade50,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode ? const Color(0xFFFF5252) : Colors.red.shade300, 
                    width: 2
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF3D2525) : Colors.red.shade100,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, 
                               color: isDarkMode ? const Color(0xFFFF5252) : Colors.red.shade700, 
                               size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentAlerts.length == 1 
                                  ? 'Alert from Other Incubator'
                                  : 'Alerts from Other Incubators',
                              style: TextStyle(
                                color: isDarkMode ? const Color(0xFFFF5252) : Colors.red.shade700,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${currentAlerts.length}',
                            style: TextStyle(
                              color: isDarkMode ? const Color(0xFFFF5252) : Colors.red.shade700,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: currentAlerts.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final alert = currentAlerts[index];
                          final isCritical = alert['severity'] == 'critical';
                          
                          return Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isCritical 
                                  ? (isDarkMode ? const Color(0xFF3D2525) : Colors.red.shade100)
                                  : (isDarkMode ? const Color(0xFF3D2B1F) : Colors.orange.shade100),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCritical 
                                    ? (isDarkMode ? const Color(0xFFFF5252) : Colors.red.shade300)
                                    : (isDarkMode ? const Color(0xFFFF8C42) : Colors.orange.shade300),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  alert['icon'],
                                  color: isCritical 
                                      ? (isDarkMode ? const Color(0xFFFF5252) : Colors.red.shade700)
                                      : (isDarkMode ? const Color(0xFFFF8C42) : Colors.orange.shade700),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alert['incubator'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isCritical 
                                              ? (isDarkMode ? const Color(0xFFFF5252) : Colors.red.shade700)
                                              : (isDarkMode ? const Color(0xFFFF8C42) : Colors.orange.shade700),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        alert['message'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCritical 
                                        ? (isDarkMode ? const Color(0xFF5D3A3A) : Colors.red.shade200)
                                        : (isDarkMode ? const Color(0xFF5D4A33) : Colors.orange.shade200),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isCritical ? 'CRITICAL' : 'WARNING',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isCritical 
                                          ? (isDarkMode ? const Color(0xFFFF5252) : Colors.red.shade700)
                                          : (isDarkMode ? const Color(0xFFFF8C42) : Colors.orange.shade700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _dismissWarning();
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Dismiss'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode ? const Color(0xFFFF5252) : Colors.red.shade600,
                            foregroundColor: isDarkMode ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCandlingRowWithScheduled(String label, bool isDone, bool isDarkMode, int day, String incubatorName) {
    final String scheduleKey = '${incubatorName}_day_$day';
    final bool isScheduled = widget.scheduledCandlingData?.containsKey(scheduleKey) ?? false;
    Map<String, dynamic>? scheduleInfo;
    if (isScheduled) {
      scheduleInfo = widget.scheduledCandlingData![scheduleKey];
    }

    return GestureDetector(
      onTap: () {
        if (isScheduled) {
          _showEditScheduleDialog(scheduleKey, scheduleInfo!, day, incubatorName);
        } else {
          showCandlingDialog(context, incubatorData[selectedIncubator]!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
          border: isScheduled ? Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 1,
          ) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  if (isScheduled) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Scheduled: ${scheduleInfo!['scheduledDate'].day}/${scheduleInfo['scheduledDate'].month}/${scheduleInfo['scheduledDate'].year}',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Tap to edit schedule',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                if (isScheduled) ...[
                  Icon(
                    Icons.edit_calendar,
                    color: Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isDone 
                      ? (isDarkMode ? const Color(0xFF40C057) : Colors.green)
                      : (isDarkMode ? const Color(0xFF666666) : Colors.grey),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void showCandlingDialog(BuildContext context, Map<String, dynamic> data) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final int daysElapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(data['startDate'] ?? DateTime.now().millisecondsSinceEpoch)
    ).inDays;
    
    final List<int> availableDays = [7, 14, 18].where((day) => daysElapsed >= day).toList();
    final TextEditingController viableEggController = TextEditingController(
      text: (data['viableEggs'] ?? data['eggCount'] ?? 0).toString()
    );
    
    Navigator.pop(context); 
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Candling Progress',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mark completed candling days and update viable egg count:',
                    style: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ...availableDays.map((day) {
                    final bool currentStatus = data['candlingDates']['$day'] ?? false;
                    return CheckboxListTile(
                      title: Text(
                        'Day $day Candling',
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      ),
                      value: currentStatus,
                      activeColor: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue,
                      checkColor: Colors.white,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          data['candlingDates']['$day'] = value ?? false;
                          if (day == 7 && value == true && data['fertilityRate'] == null) {
                            final viableCount = int.tryParse(viableEggController.text) ?? (data['viableEggs'] ?? data['eggCount'] ?? 0);
                            data['fertilityRate'] = ((viableCount / (data['eggCount'] ?? 1)) * 100);
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  TextField(
                    controller: viableEggController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Viable Eggs Remaining',
                      labelStyle: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600]),
                      hintText: 'Update count after candling',
                      hintStyle: TextStyle(color: isDarkMode ? const Color(0xFF666666) : Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDarkMode ? const Color(0xFF444444) : Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue),
                      ),
                    ),
                    onChanged: (value) {
                      final int viableCount = int.tryParse(value) ?? 0;
                      setDialogState(() {
                        data['viableEggs'] = viableCount;
                        if (data['candlingDates']['7'] == true) {
                          data['fertilityRate'] = ((viableCount / (data['eggCount'] ?? 1)) * 100);
                        }
                      });
                    },
                  ),
                  if (data['fertilityRate'] != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Fertility Rate: ${data['fertilityRate'].toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); 
                  showBatchDialog(context, incubatorData[selectedIncubator]!);
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    final String incubatorKey = selectedIncubator;
                    if (incubatorData.containsKey(incubatorKey)) {
                      incubatorData[incubatorKey]!['candlingDates'] = Map<String, dynamic>.from(data['candlingDates'] ?? {});
                      if (data['fertilityRate'] != null) {
                        incubatorData[incubatorKey]!['fertilityRate'] = data['fertilityRate'];
                      }
                      if (data['viableEggs'] != null) {
                        incubatorData[incubatorKey]!['viableEggs'] = data['viableEggs'];
                      }
                    }
                    _notifyDataChanged();
                  });
                  Navigator.pop(context); 
                  showBatchDialog(context, incubatorData[selectedIncubator]!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Candling progress saved!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void showHatchResultDialog(BuildContext context, Map<String, dynamic> data) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController hatchedController = TextEditingController();
    
    Navigator.pop(context); 
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.celebration,
              color: isDarkMode ? const Color(0xFF40C057) : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              'Record Hatch Results',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Congratulations! Your batch is ready to hatch.',
                style: TextStyle(
                  color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Initial eggs:',
                          style: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600]),
                        ),
                        Text(
                          '${data['eggCount'] ?? 0}',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Viable before hatch:',
                          style: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600]),
                        ),
                        Text(
                          '${data['viableEggs'] ?? data['eggCount'] ?? 0}',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hatchedController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Successfully Hatched *',
                  labelStyle: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600]),
                  hintText: 'Number of chicks hatched',
                  hintStyle: TextStyle(color: isDarkMode ? const Color(0xFF666666) : Colors.grey[400]),
                  prefixIcon: Icon(
                    Icons.egg_alt,
                    color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blue,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDarkMode ? const Color(0xFF444444) : Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDarkMode ? const Color(0xFF40C057) : Colors.green),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              showBatchDialog(context, incubatorData[selectedIncubator]!);
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final int hatchedCount = int.tryParse(hatchedController.text) ?? 0;
              final int viableEggs = data['viableEggs'] ?? data['eggCount'] ?? 1;
              
              if (hatchedCount >= 0 && hatchedCount <= viableEggs) {
                setState(() {
                  data['hatchedCount'] = hatchedCount;
                });
                _notifyDataChanged();
                
                _addBatchToHistory(data, selectedIncubator, reason: 'Completed');
                
                Navigator.pop(context); 

                showBatchDialog(context, incubatorData[selectedIncubator]!);
                
                final double successRate = (hatchedCount / (data['eggCount'] ?? 1)) * 100;
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Batch completed! $hatchedCount chicks hatched (${successRate.toStringAsFixed(1)}% success rate)',
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                  ),
                );
              } else if (hatchedCount > viableEggs) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cannot hatch more than $viableEggs viable eggs'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? const Color(0xFF40C057) : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditScheduleDialog(String scheduleKey, Map<String, dynamic> scheduleInfo, int candlingDay, String incubatorName) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final DateTime currentScheduledDate = scheduleInfo['scheduledDate'];
    final String batchName = scheduleInfo['batchName'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : null,
        title: Row(
          children: [
            Icon(Icons.edit_calendar, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Edit Candling Schedule',
                style: TextStyle(color: isDarkMode ? Colors.white : null),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$incubatorName - $batchName',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Day $candlingDay Candling',
              style: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(
              'Current scheduled date:',
              style: TextStyle(color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${currentScheduledDate.day}/${currentScheduledDate.month}/${currentScheduledDate.year}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showRescheduleDatePicker(scheduleKey, scheduleInfo, candlingDay, incubatorName);
            },
            child: const Text('Reschedule'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeSchedule(scheduleKey);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showRescheduleDatePicker(String scheduleKey, Map<String, dynamic> scheduleInfo, int candlingDay, String incubatorName) {
    final DateTime currentDate = scheduleInfo['scheduledDate'];
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    final DateTime initialDate = currentDate.isAfter(tomorrow) ? currentDate : tomorrow;

    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Reschedule Candling',
      confirmText: 'Update',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.orange,
            ),
          ),
          child: child!,
        );
      },
    ).then((selectedDate) {
      if (selectedDate != null) {
        _updateSchedule(scheduleKey, scheduleInfo, selectedDate);
      }
    });
  }

  void _updateSchedule(String scheduleKey, Map<String, dynamic> scheduleInfo, DateTime newDate) {
    final updatedSchedule = Map<String, dynamic>.from(scheduleInfo);
    updatedSchedule['scheduledDate'] = newDate;
    updatedSchedule['dateScheduled'] = DateTime.now();

    final Map<String, Map<String, dynamic>> updatedAllSchedules = 
        Map.from(widget.scheduledCandlingData ?? {});
    updatedAllSchedules[scheduleKey] = updatedSchedule;

    _notifyScheduleChange(updatedAllSchedules);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Candling rescheduled to ${newDate.day}/${newDate.month}/${newDate.year}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeSchedule(String scheduleKey) {
    final Map<String, Map<String, dynamic>> updatedAllSchedules = 
        Map.from(widget.scheduledCandlingData ?? {});
    updatedAllSchedules.remove(scheduleKey);

    _notifyScheduleChange(updatedAllSchedules);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Candling schedule removed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _notifyScheduleChange(Map<String, Map<String, dynamic>> updatedSchedules) {
    if (widget.onScheduleChanged != null) {
      widget.onScheduleChanged!(updatedSchedules);
    }
  }
}
