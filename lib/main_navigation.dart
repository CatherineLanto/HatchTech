import 'package:flutter/material.dart';
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

  void _navigateToDashboard(String incubatorName) {
    setState(() {
      selectedIncubatorName = incubatorName;
      _currentIndex = 1; // Switch to Dashboard tab
    });
  }

  void _navigateToAnalytics() {
    setState(() {
      _currentIndex = 2; // Switch to Analytics tab
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
            key: ValueKey('overview_$currentUserName'), // Force rebuild when username changes
            userName: currentUserName,
            themeNotifier: widget.themeNotifier,
            sharedIncubatorData: sharedIncubatorData.isNotEmpty ? sharedIncubatorData : null,
            onDataChanged: _updateSharedData,
            onUserNameChanged: _updateUserName,
            onNavigateToDashboard: _navigateToDashboard,
            onNavigateToAnalytics: _navigateToAnalytics,
          ),
          Dashboard(
            key: ValueKey('dashboard_${currentUserName}_$selectedIncubatorName'), // Force rebuild when username or incubator changes
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
          ),
          AnalyticsScreen(
            key: ValueKey('analytics_$currentUserName'), // Force rebuild when username changes
            userName: currentUserName,
            themeNotifier: widget.themeNotifier,
            incubatorData: sharedIncubatorData,
            onNavigateToDashboard: _navigateToDashboard,
            onCandlingScheduled: _updateScheduledCandling,
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
