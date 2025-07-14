import 'package:flutter/material.dart';
import 'package:hatchtech/login_screen.dart'; // Make sure this path is correct

class ProfileScreen extends StatelessWidget {
  final Map<String, Map<String, dynamic>> incubatorData;
  final String selectedIncubator;

  const ProfileScreen({
    super.key,
    required this.incubatorData,
    required this.selectedIncubator,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.lightBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage('https://placehold.co/600x600'),
            ),
            const SizedBox(height: 20),
            Text(
              'Admin User',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            const Text('HatchTech Administrator'),
            const Divider(height: 40),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: const Text('admin@hatchtech.com'),
            ),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('Manage Incubators'),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => IncubatorManager(
                    incubatorData: incubatorData,
                    onDelete: (name) {
                      incubatorData.remove(name);
                      Navigator.pop(context); // Close bottom sheet
                      Navigator.pop(context, true); // Notify Dashboard
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IncubatorManager extends StatelessWidget {
  final Map<String, Map<String, dynamic>> incubatorData;
  final Function(String) onDelete;

  const IncubatorManager({
    super.key,
    required this.incubatorData,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      children: incubatorData.keys.map((key) {
        return ListTile(
          title: Text(key),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Delete "$key"?'),
                content: const Text('Are you sure you want to remove this incubator?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
                    onPressed: () {
                      onDelete(key);
                      Navigator.pop(ctx); // Close dialog
                    },
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
