import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(HatchTechApp());
}

class HatchTechApp extends StatelessWidget {
  const HatchTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.egg, size: 80, color: Colors.orange),
              SizedBox(height: 20),
              Text('HatchTech', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.person),
                  hintText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.lock),
                  hintText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text('Forgot Password?'),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => Dashboard()));
                },
                child: Text('Log In'),
              ),
              SizedBox(height: 10),
              Text("Don't have an account? Sign Up"),
            ],
          ),
        ),
      ),
    );
  }
}

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
    Timer(Duration(milliseconds: 500), () {
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

  void deleteIncubator(String name) {
    if (incubatorData.length <= 1) return;
    incubatorData.remove(name);
    setState(() {
      selectedIncubator = incubatorData.keys.first;
      showWarning = false;
      checkHumidityWarning();
    });
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
        title: Text('Dashboard'),
        backgroundColor: Colors.lightBlue,
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            tooltip: 'Remove Incubator',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Remove $selectedIncubator?'),
                  content: Text('Are you sure you want to remove this incubator?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        deleteIncubator(selectedIncubator);
                      },
                      child: Text('Remove', style: TextStyle(color: Colors.red)),
                    )
                  ],
                ),
              );
            },
          ),
          IconButton(onPressed: () {}, icon: Icon(Icons.account_circle))
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
                              return DropdownMenuItem(value: key, child: Text(key));
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedIncubator = value!;
                                showWarning = false;
                                checkHumidityWarning();
                              });
                            },
                            decoration: InputDecoration(border: OutlineInputBorder()),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: addNewIncubator,
                          icon: Icon(Icons.add),
                          label: Text('Add'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
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
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: isCritical ? Colors.red : Colors.blue),
          SizedBox(height: 10),
          CircularProgressIndicator(
            value: value / max,
            color: isCritical ? Colors.red : Colors.blue,
            strokeWidth: 6,
          ),
          SizedBox(height: 10),
          Text(value.toStringAsFixed(1), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
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
          SizedBox(height: 10),
          Switch(value: isOn, onChanged: onChanged),
          Text(label),
        ],
      ),
    );
  }

  Widget buildWarningOverlay(double humidity) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(30),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, color: Colors.red, size: 40),
            SizedBox(height: 10),
            Text(
              'Warning!\nLow humidity detected: ${humidity.toStringAsFixed(0)}%.\nRisk of poor hatchability.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  showWarning = false;
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }
}
