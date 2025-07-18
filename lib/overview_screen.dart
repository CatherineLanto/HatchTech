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

  Map<String, Map<String, dynamic>> incubatorData = {
    'Incubator 1': {
      'temperature': 37.0,
      'humidity': 35.0,
      'oxygen': 20.0,
      'co2': 800.0,
      'eggTurning': true,
      'lighting': true
    },
    'Incubator 2': {
      'temperature': 38.2,
      'humidity': 60.0,
      'oxygen': 17.5,
      'co2': 1100.0,
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
  }

  void updateIncubatorData(Map<String, Map<String, dynamic>> newData) {
    if (mounted) {
      setState(() {
        incubatorData = newData;
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

      if (values['humidity'] < 30 || values['humidity'] > 70) {
        issues.add("Humidity out of range");
      }
      if (values['temperature'] < 35 || values['temperature'] > 40) {
        issues.add("Temperature out of range");
      }
      if (values['oxygen'] < 18) {
        issues.add("Low oxygen level");
      }
      if (values['co2'] > 1000) {
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

              if (result is String && result.isNotEmpty) {
                setState(() {
                  userName = result;
                });
              }

              if (result == true || result is String) {
                setState(() {
                  incubators = incubatorData.keys.toList();
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
            "Welcome back, $userName!",
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          Card(
            color: Colors.green.shade100,
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.check_circle,
                  color: Colors.green, size: 32),
              title: const Text("System Status",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                warningCount > 0
                    ? "$normalCount incubator(s) are functioning within optimal parameters."
                    : "All incubator(s) are functioning within optimal parameters.",
              ),
            ),
          ),

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
            ...warningIncubators.map((incubator) => Card(
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
                        const Icon(Icons.error, color: Colors.red),
                      ],
                    ),
                  ),
                )),
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
                    final result = await Navigator.push(
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
                    if (result != null &&
                        result is Map<String, Map<String, dynamic>>) {
                      updateIncubatorData(result);
                    }
                  },
                ),
              )),
        ],
      ),
    );
  }
}
