import 'package:flutter/material.dart';
import 'package:hatchtech/profile_screen.dart';
import 'dart:async';
import 'dart:math';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String selectedIncubator = 'Incubator 1';

  final Map<String, Map<String, dynamic>> incubatorData = {
    'Incubator 1': {
      'temperature': 37.0,
      'humidity': 35.0,
      'oxygen': 34.0,
      'co2': 48.0,
      'eggTurning': true,
      'lighting': true,
    },
    'Incubator 2': {
      'temperature': 38.5,
      'humidity': 55.0,
      'oxygen': 36.0,
      'co2': 46.0,
      'eggTurning': false,
      'lighting': false,
    },
  };

  bool showWarning = false;
  late Timer dataUpdateTimer;

  @override
  void initState() {
    super.initState();
    checkHumidityWarning();
    dataUpdateTimer = Timer.periodic(Duration(seconds: 5), (_) => updateSensorData());
  }

  void updateSensorData() {
    setState(() {
      incubatorData.forEach((key, value) {
        value['temperature'] += (Random().nextDouble() - 0.5);
        value['humidity'] += (Random().nextDouble() - 0.5);
        value['oxygen'] += (Random().nextDouble() - 0.3);
        value['co2'] += (Random().nextDouble() - 0.3);
      });
    });
  }

  void checkHumidityWarning() {
    double humidity = incubatorData[selectedIncubator]!['humidity'];
    Timer(const Duration(milliseconds: 500), () {
      if (humidity < 40.0) {
        setState(() {
          showWarning = true;
        });
      }
    });
  }

  void addNewIncubator() {
    int count = incubatorData.length + 1;
    String newName = 'Incubator $count';
    Random rand = Random();

    incubatorData[newName] = {
      'temperature': 36.0 + rand.nextDouble() * 3,
      'humidity': 30.0 + rand.nextDouble() * 40,
      'oxygen': 30.0 + rand.nextDouble() * 10,
      'co2': 40.0 + rand.nextDouble() * 10,
      'eggTurning': rand.nextBool(),
      'lighting': rand.nextBool(),
    };

    setState(() {
      selectedIncubator = newName;
      showWarning = false;
      checkHumidityWarning();
    });
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
    dataUpdateTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double temperature = incubatorData[selectedIncubator]!['temperature'];
    double humidity = incubatorData[selectedIncubator]!['humidity'];
    double oxygen = incubatorData[selectedIncubator]!['oxygen'];
    double co2 = incubatorData[selectedIncubator]!['co2'];
    bool eggTurning = incubatorData[selectedIncubator]!['eggTurning'];
    bool lighting = incubatorData[selectedIncubator]!['lighting'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.lightBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
  value: selectedIncubator,
  items: incubatorData.keys.map((key) {
    return DropdownMenuItem(
      value: key,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key),
          GestureDetector(
            onTap: () {
              Navigator.pop(context); // Close dropdown
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showRenameDialog(context, key);
              });
            },
            child: const Icon(Icons.edit, size: 18),
          ),
        ],
      ),
    );
  }).toList(),
  selectedItemBuilder: (context) {
    // This determines what shows in the collapsed dropdown
    return incubatorData.keys.map((key) {
      return Text(key); // Only show plain text here
    }).toList();
  },
  onChanged: (value) {
    if (value != null) {
      setState(() {
        selectedIncubator = value;
        showWarning = false;
        checkHumidityWarning();
      });
    }
  },
  decoration: const InputDecoration(
    border: OutlineInputBorder(),
  ),
),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: addNewIncubator,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: [
                          buildSensorCard('Temperature', temperature, Icons.thermostat, max: 40),
                          buildSensorCard('Humidity', humidity, Icons.water_drop, isCritical: humidity < 40, max: 100),
                          buildSensorCard('Oxygen Levels', oxygen, Icons.air, max: 100),
                          buildSensorCard('CO₂ Levels', co2, Icons.cloud, max: 100),
                          buildToggleCard('Egg Turning', eggTurning, (val) {
                            setState(() {
                              incubatorData[selectedIncubator]!['eggTurning'] = val;
                            });
                          }),
                          buildToggleCard('Lighting', lighting, (val) {
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
              if (showWarning) buildWarningOverlay(humidity),
            ],
          );
        },
      ),
    );
  }

  Widget buildSensorCard(String label, double value, IconData icon, {bool isCritical = false, double max = 100}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[100]!, Colors.blue[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: isCritical ? Colors.red : Colors.blue),
          const SizedBox(height: 10),
          CircularProgressIndicator(
            value: value / max,
            color: isCritical ? Colors.red : Colors.blue,
            strokeWidth: 6,
          ),
          const SizedBox(height: 10),
          Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget buildToggleCard(String label, bool isOn, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.lightBlue[50],
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            label == 'Egg Turning' ? Icons.sync : Icons.lightbulb,
            size: 40,
            color: Colors.blue,
          ),
          const SizedBox(height: 10),
          Switch(value: isOn, onChanged: onChanged),
          Text(label),
        ],
      ),
    );
  }

  Widget buildWarningOverlay(double humidity) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(30),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 40),
            const SizedBox(height: 10),
            Text(
              'Warning!\nLow humidity detected: ${humidity.toStringAsFixed(0)}%.\nRisk of poor hatchability.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  showWarning = false;
                });
              },
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }
}
