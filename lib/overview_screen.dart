import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'profile_screen.dart';

class OverviewPage extends StatelessWidget {
  final String userName;
  final int normalCount;
  final int warningCount;
  final List<String> incubators;
  final ValueNotifier<ThemeMode> themeNotifier;

  const OverviewPage({
    super.key,
    required this.userName,
    required this.themeNotifier,
    this.normalCount = 4,
    this.warningCount = 1,
    this.incubators = const ['Incubator 1', 'Incubator 2'],
  });

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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    incubatorData: const {}, // Empty data for now
                    selectedIncubator: incubators.isNotEmpty ? incubators.first : '',
                    themeNotifier: themeNotifier,
                  ),
                ),
              );
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
              "Welcome back, $userName!",
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Dashboard(
                        incubatorName: incubator,
                        userName: userName,
                        themeNotifier: themeNotifier,
                      ),
                    ),
                  );
                },
              ),
            )),
          ],
        ),
      ),
    );
  }
}
