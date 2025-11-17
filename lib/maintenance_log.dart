import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'profile_screen.dart';
import 'services/auth_service.dart';

class MaintenanceLogPage extends StatefulWidget {
  final String incubatorId;
  final ValueNotifier<ThemeMode> themeNotifier;
  final String userName;
  final Function(String)? onUserNameChanged;
  final bool hasIncubators;

  const MaintenanceLogPage({
    super.key,
    required this.incubatorId,
    required this.themeNotifier,
    required this.userName,
    this.onUserNameChanged,
    required this.hasIncubators,
  });

  @override
  State<MaintenanceLogPage> createState() => _MaintenanceLogPageState();
}

class _MaintenanceLogPageState extends State<MaintenanceLogPage> {
  List<Map<String, dynamic>> logs = [];
  late String userName;

  @override
  void initState() {
    super.initState();
    userName = widget.userName;
    loadLogs();
  }

  void loadLogs() async {
    final ref = FirebaseDatabase.instance
        .ref("HatchTech/${widget.incubatorId}/maintenance/history");
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final Map data = Map<String, dynamic>.from(snapshot.value as Map);
      final List<Map<String, dynamic>> sortedLogs = data.entries.map((e) {
        final log = Map<String, dynamic>.from(e.value);
        log['timestamp'] = e.key;
        return log;
      }).toList()
        ..sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      setState(() => logs = sortedLogs);
      cleanupOldLogs(ref, sortedLogs);
    }
  }

  void cleanupOldLogs(DatabaseReference ref, List<Map<String, dynamic>> logs) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    for (var log in logs) {
      final timestamp = DateTime.tryParse(log['timestamp'] ?? '');
      if (timestamp != null && timestamp.isBefore(cutoff)) {
        ref.child(log['timestamp']).remove();
      }
    }
  }

  // You will need to add this helper function into your _MaintenanceScreenState class.
Future<void> _showProfileModal(BuildContext context) async {
  // IMPORTANT: The variable 'userName' and methods like 'AuthService.getUserData()'
  // must be correctly defined and accessible within your _MaintenanceScreenState.
  
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // NOTE: ProfileScreen requires incubatorData and selectedIncubator. 
        // Using empty placeholders {} and '' to match your original code structure.
        child: ProfileScreen(
          userName: userName, // Assuming 'userName' is a state variable
          themeNotifier: widget.themeNotifier,
          incubatorData: const {}, 
          selectedIncubator: '',
          onUserNameChanged: () async {
            final userData = await AuthService.getUserData();
            if (mounted && userData != null) {
              setState(() {
                // This assumes a state variable 'userName' exists in the state class
                userName = userData['username'] ?? userName;
              });
              widget.onUserNameChanged?.call(userName);
            }
          },
        ),
      ),
    ),
  );
}

@override
Widget build(BuildContext context) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  return Scaffold( // Scaffold is now always returned
    appBar: AppBar( // AppBar is now always returned
      title: const Text(
        "Maintenance",
      ),
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.person),
          onPressed: () => _showProfileModal(context), // Use the extracted function
        ),
      ],
    ),
    body: !widget.hasIncubators // Conditional Body based on hasIncubators
        ? const Center(
            child: Text(
              "Add an incubator to view maintenance logs.",
              style: TextStyle(fontSize: 16),
            ),
          )
        : logs.isEmpty
            ? const Center( // Case: Has incubators, but no logs
                child: Text(
                  "No maintenance history yet.",
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
              )
            : Padding( // Case: Has incubators AND logs
                padding: const EdgeInsets.all(16.0),
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final date = DateTime.tryParse(log['timestamp'] ?? '');
                    final formattedDate = date != null
                        ? "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"
                        : "Unknown Date";

                    return Card(
                      elevation: 2,
                      color: isDarkMode
                          ? const Color(0xFF0F1B2D)
                          : const Color(0xFFE3F2FD),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.build_rounded,
                            color: Colors.blueAccent),
                        title: Text(
                          log['type']?.toString().toUpperCase() ??
                              "Maintenance Task",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(log['message'] ?? "No details available"),
                        trailing: Text(
                          formattedDate,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ),
  );
}
}
