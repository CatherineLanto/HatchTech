import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'overview_screen.dart';
import 'dashboard.dart';
import 'analytics_screen.dart';

class MainNavigation extends StatefulWidget {
  final String userName;
  final ValueNotifier<ThemeMode> themeNotifier;

  const MainNavigation({
    super.key,
    required this.userName,
    required this.themeNotifier,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late String currentUserName;
  String selectedIncubatorName = '';
  Map<String, Map<String, dynamic>> sharedIncubatorData = {};
  Map<String, Map<String, dynamic>> scheduledCandlingData = {};
  List<Map<String, dynamic>> batchHistory = [];

  @override
  void initState() {
    super.initState();
    currentUserName = widget.userName;
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
            sharedIncubatorData: sharedIncubatorData.isNotEmpty ? sharedIncubatorData : null,
            batchHistory: batchHistory,
            onDataChanged: _updateSharedData,
            onUserNameChanged: _updateUserName,
            onNavigateToDashboard: _navigateToDashboard,
            onNavigateToAnalytics: _navigateToAnalytics,
          ),
          Dashboard(
            key: ValueKey('dashboard_${currentUserName}_$selectedIncubatorName'), 
            incubatorName: selectedIncubatorName.isNotEmpty 
                ? selectedIncubatorName 
                : (sharedIncubatorData.isNotEmpty ? sharedIncubatorData.keys.first : 'Incubator 1'),
            userName: currentUserName,
            themeNotifier: widget.themeNotifier,
            incubatorData: sharedIncubatorData.isNotEmpty ? sharedIncubatorData : null,
            scheduledCandlingData: scheduledCandlingData,
            onDataChanged: _updateSharedData,
            onUserNameChanged: _updateUserName,
            onScheduleChanged: _updateScheduledCandling,
            onBatchHistoryChanged: _updateBatchHistory,
          ),
          AnalyticsScreen(
            key: ValueKey('analytics_$currentUserName'), 
            userName: currentUserName,
            themeNotifier: widget.themeNotifier,
            onNavigateToDashboard: _navigateToDashboard,
            onCandlingScheduled: _updateScheduledCandling,
            onDeleteBatch: _deleteBatchFromHistory,
            onBatchHistoryChanged: _refreshBatchHistory,
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
        ],
      ),
    );
  }
}