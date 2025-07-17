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
  
  const Dashboard({
    super.key, 
    required this.incubatorName, 
    required this.userName, 
    required this.themeNotifier,
    this.incubatorData,
    this.onDataChanged,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String selectedIncubator = 'Incubator 1';
  bool showWarning = false;
  String warningMessage = '';
  late Timer dataUpdateTimer;
  DateTime? lastAlertTime;
  final Duration alertCooldown = const Duration(seconds: 10);
  bool isDropdownOpen = false;
  FocusNode dropdownFocusNode = FocusNode();

  final Map<String, Map<String, dynamic>> incubatorData = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize with passed data or default data
    if (widget.incubatorData != null && widget.incubatorData!.isNotEmpty) {
      incubatorData.addAll(widget.incubatorData!);
    } else {
      incubatorData.addAll({
        'Incubator 1': {'temperature': 37.0, 'humidity': 35.0, 'oxygen': 20.0, 'co2': 800.0, 'eggTurning': true, 'lighting': true},
        'Incubator 2': {'temperature': 38.2, 'humidity': 60.0, 'oxygen': 19.5, 'co2': 900.0, 'eggTurning': false, 'lighting': false},
      });
    }
    
    selectedIncubator = widget.incubatorName;
    dataUpdateTimer = Timer.periodic(const Duration(seconds: 4), (_) => updateSensorData());
  }

  void updateSensorData() {
    setState(() {
      incubatorData.forEach((key, values) {
        values['temperature'] += (Random().nextDouble() - 0.5);
        values['humidity'] += (Random().nextDouble() - 0.5);
        values['oxygen'] += (Random().nextDouble() - 0.3);
        values['co2'] += (Random().nextDouble() * 10 - 5);
      });
      checkAlerts();
    });
  }

  void checkAlerts() {
    final now = DateTime.now();
    if (lastAlertTime != null && now.difference(lastAlertTime!) < alertCooldown) return;

    List<String> alerts = [];

    incubatorData.forEach((key, values) {
      if (values['humidity'] < 40) {
        alerts.add('$key: Low Humidity (${values['humidity'].toStringAsFixed(1)}%)');
      }
      if (values['temperature'] < 36.5 || values['temperature'] > 38.5) {
        alerts.add('$key: Abnormal Temp (${values['temperature'].toStringAsFixed(1)}°C)');
      }
      if (values['oxygen'] < 18.0) {
        alerts.add('$key: Low Oxygen (${values['oxygen'].toStringAsFixed(1)}%)');
      }
      if (values['co2'] > 1000) {
        alerts.add('$key: High CO₂ (${values['co2'].toStringAsFixed(0)} ppm)');
      }
    });

    if (alerts.isNotEmpty) {
      setState(() {
        warningMessage = alerts[Random().nextInt(alerts.length)];
        showWarning = true;
        lastAlertTime = now;
      });
    }
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
    _notifyDataChanged(); // Notify parent about the change
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
              _notifyDataChanged(); // Notify parent about the change
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
      onPopInvoked: (didPop) {
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
              bool? updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    incubatorData: incubatorData,
                    selectedIncubator: selectedIncubator,
                    themeNotifier: widget.themeNotifier,
                    userName: widget.userName,
                  ),
                ),
              );

              if (updated == true) {
                setState(() {
                  if (!incubatorData.containsKey(selectedIncubator)) {
                    selectedIncubator = incubatorData.keys.first;
                  }
                  checkAlerts();
                });
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
                                      Navigator.pop(context); 
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
          if (showWarning) buildWarningDialog(),
        ],
      ),
    )
    );
  }

  Widget buildSensorCard(String label, double value, IconData icon, {double max = 100}) {
    double percentage = value / max;
    Color barColor = (label == 'Humidity' && value < 40) ||
            (label == 'Temperature' && (value < 36.5 || value > 38.5)) ||
            (label == 'Oxygen' && value < 18.0) ||
            (label == 'CO₂' && value > 1000)
        ? Colors.red
        : Colors.blue;

    return Container(
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
          Icon(icon, size: 40, color: barColor),
          const SizedBox(height: 10),
          CircularProgressIndicator(
            value: percentage.clamp(0.0, 1.0),
            color: barColor,
            strokeWidth: 6,
          ),
          const SizedBox(height: 10),
          Text(
            value.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(label),
        ],
      ),
    );
  }

  Widget buildToggleCard(String label, bool isOn, Function(bool) onChanged) {
    IconData icon = label == 'Lighting' ? Icons.lightbulb : Icons.sync;
    Color iconColor = isOn ? Colors.green : Colors.grey;

    return Container(
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
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(height: 10),
          Switch(value: isOn, onChanged: onChanged),
          Text(label),
        ],
      ),
    );
  }

  Widget buildWarningDialog() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(30),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 40),
            const SizedBox(height: 10),
            Text(
              warningMessage,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                setState(() => showWarning = false);
              },
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }
}
