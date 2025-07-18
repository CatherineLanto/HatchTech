import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'profile_screen.dart';

class Dashboard extends StatefulWidget {
  final String incubatorName;
  final String userName;
  final ValueNotifier<ThemeMode> themeNotifier;
  final Map<String, Map<String, dynamic>>? incubatorData;
  final Function(Map<String, Map<String, dynamic>>)? onDataChanged;
  final Function(String)? onUserNameChanged;
  
  const Dashboard({
    super.key, 
    required this.incubatorName, 
    required this.userName, 
    required this.themeNotifier,
    this.incubatorData,
    this.onDataChanged,
    this.onUserNameChanged,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  String selectedIncubator = 'Incubator 1';
  bool showWarning = false;
  List<Map<String, dynamic>> currentAlerts = [];
  late Timer dataUpdateTimer;
  Timer? _autoDismissTimer;
  DateTime? lastAlertTime;
  final Duration alertCooldown = const Duration(seconds: 20);
  bool isDropdownOpen = false;
  FocusNode dropdownFocusNode = FocusNode();
  late String currentUserName;
  late AnimationController _warningAnimationController;
  late Animation<double> _warningAnimation;

  final Map<String, Map<String, dynamic>> incubatorData = {};

  @override
  void initState() {
    super.initState();
    
    currentUserName = widget.userName;
    
    // Initialize animation controller
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
      // Set better default values within optimal ranges
      incubatorData.addAll({
        'Incubator 1': {'temperature': 37.5, 'humidity': 50.0, 'oxygen': 20.5, 'co2': 800.0, 'eggTurning': true, 'lighting': true},
        'Incubator 2': {'temperature': 37.8, 'humidity': 55.0, 'oxygen': 20.0, 'co2': 750.0, 'eggTurning': false, 'lighting': false},
      });
    }
    
    selectedIncubator = widget.incubatorName;
    // Reasonable update frequency for good user experience
    dataUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) => updateSensorData());
  }

  void updateSensorData() {
    setState(() {
      incubatorData.forEach((key, values) {
        // More realistic simulation ranges that occasionally cross thresholds
        values['temperature'] = _clampValue(
          values['temperature'] + (Random().nextDouble() - 0.5) * 0.8, // Smaller temperature changes
          35.0, 40.0 // Realistic range
        );
        values['humidity'] = _clampValue(
          values['humidity'] + (Random().nextDouble() - 0.5) * 6.0, // Moderate humidity changes
          30.0, 70.0 // Range that sometimes goes out of 35-65% optimal
        );
        values['oxygen'] = _clampValue(
          values['oxygen'] + (Random().nextDouble() - 0.5) * 1.0, // Small oxygen variation
          18.0, 22.0 // Range that occasionally drops below 19%
        );
        values['co2'] = _clampValue(
          values['co2'] + (Random().nextDouble() - 0.5) * 100, // Moderate CO2 swings
          600.0, 1100.0 // Range that sometimes crosses 900 threshold
        );
      });
      checkAlerts();
    });
    
    // Immediately notify overview of data changes for real-time synchronization
    _notifyDataChanged();
  }

  double _clampValue(double value, double min, double max) {
    return value.clamp(min, max);
  }

  void checkAlerts() {
    final now = DateTime.now();
    if (lastAlertTime != null && now.difference(lastAlertTime!) < alertCooldown) return;

    List<Map<String, dynamic>> alerts = [];

    // Only check incubators that are NOT currently selected to avoid redundancy
    incubatorData.forEach((key, values) {
      if (key == selectedIncubator) return; // Skip current incubator
      
      // Critical alerts (red)
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
      
      // Warning alerts (orange/yellow)
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
      
      // Auto-dismiss after 15 seconds for non-critical alerts
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

  void addNewIncubator() {
    int count = incubatorData.length + 1;
    String newName = 'Incubator $count';
    incubatorData[newName] = {
      'temperature': 36.5 + Random().nextDouble() * 2,
      'humidity': 40 + Random().nextDouble() * 25,
      'oxygen': 18.0 + Random().nextDouble() * 3,
      'co2': 700 + Random().nextDouble() * 400,
      'eggTurning': Random().nextBool(),
      'lighting': Random().nextBool(),
    };
    setState(() {
      selectedIncubator = newName;
    });
    checkAlerts();
    // Immediately notify overview of new incubator
    _notifyDataChanged();
  }

  void showRenameDialog(BuildContext context, String incubatorKey) {
  final TextEditingController controller = TextEditingController(text: incubatorKey);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename Incubator'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'New Incubator Name'),
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
    dataUpdateTimer.cancel();
    _autoDismissTimer?.cancel();
    _warningAnimationController.dispose();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    incubatorData: incubatorData,
                    selectedIncubator: selectedIncubator,
                    themeNotifier: widget.themeNotifier,
                    userName: currentUserName,
                  ),
                ),
              );

              // Handle both username changes (String) and incubator changes (bool)
              if (result != null) {
                // Handle username change
                if (result is String && result.isNotEmpty && result != currentUserName) {
                  setState(() {
                    currentUserName = result;
                  });
                  // Notify overview of username change
                  if (widget.onUserNameChanged != null) {
                    widget.onUserNameChanged!(result);
                  }
                }
                
                setState(() {
                  if (!incubatorData.containsKey(selectedIncubator)) {
                    selectedIncubator = incubatorData.keys.first;
                  }
                  checkAlerts();
                });
                
                // Update data callback if result indicates changes
                if (widget.onDataChanged != null) {
                  widget.onDataChanged!(Map.from(incubatorData));
                }
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
                  child: GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
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
    double percentage = value / max;
    // Use same thresholds as overview for consistent status display
    Color barColor = (label == 'Humidity' && (value < 35 || value > 65)) ||
            (label == 'Temperature' && (value < 36 || value > 39)) ||
            (label == 'Oxygen' && value < 19.0) ||
            (label == 'CO₂' && value > 900)
        ? Colors.red
        : Colors.blue;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(50),
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
              color: barColor.withAlpha(204),
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  Widget buildToggleCard(String label, bool isOn, Function(bool) onChanged) {
    IconData icon = label == 'Lighting' ? Icons.lightbulb : Icons.sync;
    Color iconColor = isOn ? Colors.green : Colors.grey;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
           color: Theme.of(context).shadowColor.withAlpha(50),
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
              return AnimatedRotation(
                duration: const Duration(milliseconds: 300),
                turns: isOn ? 0.0 : 0.25,
                child: Icon(icon, size: 40, color: color),
              );
            },
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Switch(
              key: ValueKey(isOn),
              value: isOn,
              onChanged: onChanged,
              activeColor: Colors.green,
            ),
          ),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: iconColor.withAlpha(204),
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  Widget buildWarningDialog() {
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
                    colors: [
                      Colors.red.shade50,
                      Colors.orange.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade300, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, 
                               color: Colors.red.shade700, size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentAlerts.length == 1 
                                  ? 'Alert from Other Incubator'
                                  : 'Alerts from Other Incubators',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${currentAlerts.length}',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Alerts List
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
                                  ? Colors.red.shade100 
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCritical 
                                    ? Colors.red.shade300 
                                    : Colors.orange.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  alert['icon'],
                                  color: isCritical 
                                      ? Colors.red.shade700 
                                      : Colors.orange.shade700,
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
                                              ? Colors.red.shade700 
                                              : Colors.orange.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        alert['message'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
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
                                        ? Colors.red.shade200 
                                        : Colors.orange.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isCritical ? 'CRITICAL' : 'WARNING',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isCritical 
                                          ? Colors.red.shade700 
                                          : Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Action Button
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
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
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
}
