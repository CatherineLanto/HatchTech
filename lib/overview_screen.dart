import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
      'temperature': 37.5, 
      'humidity': 50.0,  
      'oxygen': 20.5,      
      'co2': 800.0,      
      'eggTurning': true,
      'lighting': true
    },
    'Incubator 2': {
      'temperature': 37.8, 
      'humidity': 55.0,    
      'oxygen': 20.0,     
      'co2': 750.0,       
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
    _loadUserData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void updateIncubatorData(Map<String, Map<String, dynamic>> newData) {
    if (mounted) {
      setState(() {
        incubatorData = Map.from(newData);
        incubators = newData.keys.toList();
        _updateCounts();
      });
      _saveUserData();
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

    setState(() {
      normalCount = normal;
      warningCount = warnings;
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = prefs.getString('current_user') ?? '';
    
    if (currentUser.isNotEmpty) {
      final savedUsername = prefs.getString('user_name_$currentUser');
      if (savedUsername != null) {
        setState(() {
          userName = savedUsername;
        });
      }
      
      final savedData = prefs.getString('incubator_data_$currentUser');
      if (savedData != null) {
        try {
          final Map<String, dynamic> decoded = json.decode(savedData);
          setState(() {
            incubatorData = decoded.map((key, value) => 
              MapEntry(key, Map<String, dynamic>.from(value)));
            incubators = incubatorData.keys.toList();
          });
        } catch (e) {
          _initializeDefaultData();
        }
      } else {
        _initializeDefaultData();
      }
    } else {
      _initializeDefaultData();
    }
    _updateCounts();
  }

  void _initializeDefaultData() {
    setState(() {
      incubatorData = {
        'Incubator 1': {
          'temperature': 37.5,
          'humidity': 50.0,
          'oxygen': 20.5,
          'co2': 800.0,
          'eggTurning': true,
          'lighting': true
        },
        'Incubator 2': {
          'temperature': 37.8,
          'humidity': 55.0,
          'oxygen': 20.0,
          'co2': 750.0,
          'eggTurning': false,
          'lighting': false
        },
      };
      incubators = incubatorData.keys.toList();
    });
    _saveUserData();
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = prefs.getString('current_user') ?? '';
    
    if (currentUser.isNotEmpty) {
      await prefs.setString('user_name_$currentUser', userName);
      
      final dataToSave = json.encode(incubatorData);
      await prefs.setString('incubator_data_$currentUser', dataToSave);
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

              setState(() {
                incubators = List<String>.from(incubatorData.keys);
                _updateCounts();
              });
              
              if (result is String && result.isNotEmpty) {
                setState(() {
                  userName = result;
                });
                _saveUserData();
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
                            onTap: () async {
                              await Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => Dashboard(
                                    incubatorName: name,
                                    userName: userName,
                                    themeNotifier: widget.themeNotifier,
                                    incubatorData: incubatorData,
                                    onDataChanged: updateIncubatorData,
                                    onUserNameChanged: (newUserName) {
                                      setState(() {
                                        userName = newUserName;
                                      });
                                      _saveUserData();
                                    },
                                  ),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(1.0, 0.0),
                                        end: Offset.zero,
                                      ).animate(CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeInOut,
                                      )),
                                      child: child,
                                    );
                                  },
                                ),
                              );
                              
                              if (mounted) {
                                _updateCounts();
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
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? const Color(0xFF40C057) : Colors.green.shade700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "All systems normal",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode ? const Color(0xFF51CF66) : Colors.green.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
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
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Dashboard(
                          incubatorName: incubator,
                          userName: userName,
                          themeNotifier: widget.themeNotifier,
                          incubatorData: incubatorData,
                          onDataChanged: updateIncubatorData,
                          onUserNameChanged: (newUserName) {
                            setState(() {
                              userName = newUserName;
                            });
                            _saveUserData();
                          },
                        ),
                      ),
                    );
                    
                    if (mounted) {
                      _updateCounts();
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

          const SizedBox(height: 30),

          const Text(
            "Incubators",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          ...incubators.map((incubator) => Card(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  title: Text(incubator),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Dashboard(
                          incubatorName: incubator,
                          userName: userName,
                          themeNotifier: widget.themeNotifier,
                          incubatorData: incubatorData,
                          onDataChanged: updateIncubatorData,
                          onUserNameChanged: (newUserName) {
                            setState(() {
                              userName = newUserName;
                            });
                            _saveUserData();
                          },
                        ),
                      ),
                    );
                    
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
