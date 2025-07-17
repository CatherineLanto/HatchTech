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
  int normalCount = 4;
  int warningCount = 1;
  List<String> incubators = ['Incubator 1', 'Incubator 2'];
  
  // This map will hold the incubator data shared across screens
  Map<String, Map<String, dynamic>> incubatorData = {
    'Incubator 1': {'temperature': 37.0, 'humidity': 35.0, 'oxygen': 20.0, 'co2': 800.0, 'eggTurning': true, 'lighting': true},
    'Incubator 2': {'temperature': 38.2, 'humidity': 60.0, 'oxygen': 19.5, 'co2': 900.0, 'eggTurning': false, 'lighting': false},
  };

  @override
  void initState() {
    super.initState();
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
    
    for (var values in incubatorData.values) {
      bool hasWarning = false;
      
      if (values['humidity'] < 30 || values['humidity'] > 70) hasWarning = true;
      if (values['temperature'] < 35 || values['temperature'] > 40) hasWarning = true;
      if (values['oxygen'] < 18) hasWarning = true;
      if (values['co2'] > 1000) hasWarning = true;
      
      if (hasWarning) {
        warnings++;
      } else {
        normal++;
      }
    }
    
    normalCount = normal;
    warningCount = warnings;
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
                    selectedIncubator: incubators.isNotEmpty ? incubators.first : '',
                    themeNotifier: widget.themeNotifier,
                  ),
                ),
              );
              
              // Update data when returning from profile screen
              if (result == true && mounted) {
                setState(() {
                  incubators = incubatorData.keys.toList();
                  _updateCounts();
                });
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back, ${widget.userName}!",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.health_and_safety, color: Colors.green),
                title: const Text("System Health"),
                subtitle: Text("✅ $normalCount Normal   ⚠️ $warningCount Warning"),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Incubators",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...incubators.map((incubator) => Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                title: Text(incubator),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Dashboard(
                        incubatorName: incubator,
                        userName: widget.userName,
                        themeNotifier: widget.themeNotifier,
                        incubatorData: incubatorData,
                        onDataChanged: updateIncubatorData,
                      ),
                    ),
                  );
                  
                  // Update data when returning from dashboard
                  if (result != null && result is Map<String, Map<String, dynamic>>) {
                    updateIncubatorData(result);
                  }
                },
              ),
            )),
          ],
        ),
      ),
    );
  }
}
