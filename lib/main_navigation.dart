import 'package:flutter/material.dart';
import 'package:hatchtech/services/auth_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'overview_screen.dart';
import 'dashboard.dart';
import 'analytics_screen.dart';
import 'maintenance_log.dart';

class MainNavigation extends StatefulWidget {
  final String userName;
  final ValueNotifier<ThemeMode> themeNotifier;
  final bool hasIncubators;

  const MainNavigation({
    super.key, 
    required this.userName,
    required this.themeNotifier,
    required this.hasIncubators,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  String? userRole;
  int _currentIndex = 0;
  late String currentUserName;
  String selectedIncubatorName = '';
  Map<String, Map<String, dynamic>> sharedIncubatorData = {};
  Map<String, Map<String, dynamic>> scheduledCandlingData = {};
  List<Map<String, dynamic>> batchHistory = [];
  bool get hasIncubators => sharedIncubatorData.isNotEmpty;

  @override
  void initState() {
    super.initState();
    currentUserName = widget.userName;
    _loadUserRole().then((_) {
      _loadIncubatorData(); 
    });
  }

  Future<void> _loadUserRole() async {
    final userData = await AuthService.getUserData();
    if (mounted) {
      setState(() {
        userRole = userData?['role'] ?? 'user';
      });
    }
  }

  Future<void> _loadIncubatorData() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    List<String> assignedIncubatorNames = [];
    if (userDoc.exists) {
      final incubators = userDoc.data()?['incubators'];
      if (incubators is List) {
        assignedIncubatorNames = incubators.map((e) => e.toString()).toList();
      }
    }

    Map<String, Map<String, dynamic>> filteredData = {};
    if (assignedIncubatorNames.isNotEmpty) {
      for (final name in assignedIncubatorNames) {
        final incubatorDoc = await FirebaseFirestore.instance.collection('incubators').doc(name).get();
        if (incubatorDoc.exists) {
          filteredData[name] = incubatorDoc.data()!;
        }
      }
    }

    if (mounted) {
      setState(() {
        sharedIncubatorData = filteredData;
        if (selectedIncubatorName.isEmpty && filteredData.isNotEmpty) {
          selectedIncubatorName = filteredData.keys.first;
        } else if (filteredData.isEmpty) {
          selectedIncubatorName = '';
        }
      });
    }
  }

  void _updateSharedData(Map<String, Map<String, dynamic>> newData) {
    setState(() {
      sharedIncubatorData = Map.from(newData);
    });
  }

  void _updateUserName(String newUserName) {
    setState(() {
      currentUserName = newUserName;
    });
  }

  void _updateScheduledCandling(Map<String, Map<String, dynamic>> newCandlingData) {
    setState(() {
      scheduledCandlingData = Map.from(newCandlingData);
    });
  }

  void _updateBatchHistory(List<Map<String, dynamic>> newBatchHistory) {
    setState(() {
      batchHistory = List.from(newBatchHistory);
    });
  }

  void _refreshBatchHistory() {
    setState(() {
    });
  }

  void _deleteBatchFromHistory(int index) async {
    debugPrint('_deleteBatchFromHistory called with index: $index, total batches: ${batchHistory.length}');
    
    if (index >= 0 && index < batchHistory.length) {
      final batchToDelete = batchHistory[index];
      debugPrint('Deleting batch: ${batchToDelete['batchName']} at index $index');
      
      setState(() {
        batchHistory.removeAt(index);
      });
      
      debugPrint('After deletion, remaining batches: ${batchHistory.length}');
      
      try {
        final prefs = await SharedPreferences.getInstance();
        final historyJson = jsonEncode(batchHistory);
        await prefs.setString('batch_history', historyJson);
        debugPrint('Batch history saved to SharedPreferences');
      } catch (e) {
        debugPrint('Error saving updated batch history: $e');
      }
    } else {
      debugPrint('Invalid index for deletion: $index (should be 0-${batchHistory.length - 1})');
    }
  }

  void _navigateToDashboard(String incubatorName) {
    setState(() {
      selectedIncubatorName = incubatorName;
      _currentIndex = 1; 
    });
  }

  void _navigateToAnalytics() {
    setState(() {
      _currentIndex = 2; 
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
  OverviewPage(
    key: ValueKey('overview_$currentUserName'),
    userName: currentUserName,
    themeNotifier: widget.themeNotifier,
    sharedIncubatorData: sharedIncubatorData,
    batchHistory: batchHistory,
    onDataChanged: _updateSharedData,
    onUserNameChanged: _updateUserName,
    onNavigateToDashboard: _navigateToDashboard,
    onNavigateToAnalytics: _navigateToAnalytics,
    userRole: userRole,
    hasIncubators: widget.hasIncubators, 
    onNavigateToMaintenance: () {
      setState(() {
        _currentIndex = 3;
      });
    },
  ),

  Dashboard(
    key: ValueKey('dashboard_${currentUserName}_$selectedIncubatorName'),
    incubatorName: selectedIncubatorName.isNotEmpty
        ? selectedIncubatorName
        : (sharedIncubatorData.isNotEmpty ? sharedIncubatorData.keys.first : 'Incubator 1'),
    userName: currentUserName,
    themeNotifier: widget.themeNotifier,
    incubatorData: sharedIncubatorData,
    scheduledCandlingData: scheduledCandlingData,
    onDataChanged: _updateSharedData,
    onUserNameChanged: _updateUserName,
    onScheduleChanged: _updateScheduledCandling,
    onBatchHistoryChanged: _updateBatchHistory,
    userRole: userRole,
    hasIncubators: widget.hasIncubators,
  ),

  AnalyticsScreen(
    key: ValueKey('analytics_$currentUserName'),
    userName: currentUserName,
    themeNotifier: widget.themeNotifier,
    onNavigateToDashboard: _navigateToDashboard,
    onCandlingScheduled: _updateScheduledCandling,
    onDeleteBatch: _deleteBatchFromHistory,
    onBatchHistoryChanged: _refreshBatchHistory,
    userRole: userRole,
    hasIncubators: widget.hasIncubators,
  ),

  MaintenanceLogPage(
    incubatorId: 'selectedIncubatorName',
    themeNotifier: widget.themeNotifier,
    userName: currentUserName,
    hasIncubators: widget.hasIncubators,
    onUserNameChanged: _updateUserName
  ),
],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build),
            label: 'Maintenance',
          ),
        ],
      ),
    );
  }
}