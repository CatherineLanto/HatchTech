import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'profile_screen.dart';

class OverviewPage extends StatefulWidget {
  final String userName;
  final ValueNotifier<ThemeMode> themeNotifier;

  const OverviewPage({
    super.key,
    required this.userName,
    required this.themeNotifier,
  });

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late String userName;
  int normalCount = 0;
  int warningCount = 0;
  List<String> incubators = ['Incubator 1', 'Incubator 2'];
  // Remove independent timer - overview will get data from dashboard

  Map<String, Map<String, dynamic>> incubatorData = {
    'Incubator 1': {
      'temperature': 37.5, // Optimal range
      'humidity': 50.0,    // Well within 35-65% range
      'oxygen': 20.5,      // Above 19% threshold
      'co2': 800.0,        // Below 900 threshold
      'eggTurning': true,
      'lighting': true
    },
    'Incubator 2': {
      'temperature': 37.8, // Optimal range
      'humidity': 55.0,    // Well within 35-65% range  
      'oxygen': 20.0,      // Above 19% threshold
      'co2': 750.0,        // Well below 900 threshold
      'eggTurning': false,
      'lighting': false
    },
  };

  List<String> normalIncubators = [];
  List<String> warningIncubators = [];
  Map<String, List<String>> warningDetails = {};

  @override
  void initState() {
    super.initState();
    userName = widget.userName;
    _updateCounts();
    // No timer needed - overview gets data from dashboard
  }

  @override
  void dispose() {
    // No timer to dispose
    super.dispose();
  }

  // Remove simulation - overview just displays data from dashboard

  void updateIncubatorData(Map<String, Map<String, dynamic>> newData) {
    if (mounted) {
      setState(() {
        // Simply update with dashboard data - no simulation needed
        incubatorData = Map.from(newData);
        incubators = newData.keys.toList();
        _updateCounts();
      });
    }
  }

  void _updateCounts() {
    int normal = 0;
    int warnings = 0;
    normalIncubators.clear();
    warningIncubators.clear();
    warningDetails.clear();

    incubatorData.forEach((name, values) {
      List<String> issues = [];

      // More sensitive thresholds for more dynamic status changes
      if (values['humidity'] < 35 || values['humidity'] > 65) {
        issues.add("Humidity out of range");
      }
      if (values['temperature'] < 36 || values['temperature'] > 39) {
        issues.add("Temperature out of range");
      }
      if (values['oxygen'] < 19) {
        issues.add("Low oxygen level");
      }
      if (values['co2'] > 900) { // Lower threshold for more frequent warnings
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

    setState(() {
      normalCount = normal;
      warningCount = warnings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Overview"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    incubatorData: incubatorData,
                    selectedIncubator:
                        incubators.isNotEmpty ? incubators.first : '',
                    themeNotifier: widget.themeNotifier,
                    userName: userName,
                  ),
                ),
              );

              // Always update incubator list and counts when returning from profile
              // since incubators might have been added, deleted, or renamed
              setState(() {
                // Force a complete refresh of the incubator list
                incubators = List<String>.from(incubatorData.keys);
                _updateCounts();
              });
              
              // Handle username change separately
              if (result is String && result.isNotEmpty) {
                setState(() {
                  userName = result;
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
            "Welcome back, $userName!",
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // System Overview Title
          Text(
            "System Overview",
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          // Only show stable incubators section if there are stable incubators
          if (normalIncubators.isNotEmpty) ...[
            Card(
              color: Colors.green.shade100,
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
                          color: Colors.green.shade700,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Stable Incubators",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green.shade700,
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
                    ...normalIncubators.map((name) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: GestureDetector(
                          onTap: () async {
                            // Navigate directly to this incubator's dashboard
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Dashboard(
                                  incubatorName: name,
                                  userName: userName,
                                  themeNotifier: widget.themeNotifier,
                                  incubatorData: incubatorData,
                                  onDataChanged: updateIncubatorData,
                                ),
                              ),
                            );
                            
                            // Update counts when returning from dashboard
                            if (mounted) {
                              _updateCounts();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  "All systems normal",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.green.shade400,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],

          // Only show warnings section if there are warning incubators
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
                  onTap: () async {
                    // Navigate directly to this incubator's dashboard to address the warning
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Dashboard(
                          incubatorName: incubator,
                          userName: userName,
                          themeNotifier: widget.themeNotifier,
                          incubatorData: incubatorData,
                          onDataChanged: updateIncubatorData,
                        ),
                      ),
                    );
                    
                    // Update counts when returning from dashboard
                    if (mounted) {
                      _updateCounts();
                    }
                  },
                  child: Card(
                    color: Colors.orange.shade100,
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
                                  Text(
                                    incubator,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  ...warningDetails[incubator]!.map((issue) =>
                                      Text("- $issue",
                                          style: const TextStyle(fontSize: 13))),
                                ]),
                          ),
                          Column(
                            children: [
                              const Icon(Icons.error, color: Colors.red),
                              const SizedBox(height: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.orange.shade400,
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

          // Show a message when there are no status updates to display
          if (normalIncubators.isEmpty && warningIncubators.isEmpty) ...[
            const SizedBox(height: 20),
            Card(
              color: Colors.blue.shade50,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.sensors,
                      color: Colors.blue.shade600,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "System Monitoring",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "All incubators are being monitored. Status updates will appear here when conditions change.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 30),

          const Text(
            "Incubators",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          ...incubators.map((incubator) => Card(
                color: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  title: Text(incubator),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    // Navigate to dashboard - it will control the data simulation
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Dashboard(
                          incubatorName: incubator,
                          userName: userName,
                          themeNotifier: widget.themeNotifier,
                          incubatorData: incubatorData,
                          onDataChanged: updateIncubatorData,
                        ),
                      ),
                    );
                    
                    // Update counts when returning from dashboard
                    if (mounted) {
                      _updateCounts();
                    }
                  },
                ),
              )),
        ],
      ),
    );
  }
}
