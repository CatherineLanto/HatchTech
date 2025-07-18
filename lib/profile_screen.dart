import 'package:flutter/material.dart';
import 'package:hatchtech/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, Map<String, dynamic>> incubatorData;
  final String selectedIncubator;
  final ValueNotifier<ThemeMode> themeNotifier;
  final String userName;

  const ProfileScreen({
    super.key,
    required this.incubatorData,
    required this.selectedIncubator,
    required this.themeNotifier,
    required this.userName,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.themeNotifier.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: Colors.white,
            ),
            onPressed: () {
              widget.themeNotifier.value =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blueAccent,
              child: Icon(
                Icons.person,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    enabled: _isEditing,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isEditing ? Icons.check_circle : Icons.edit,
                    color: Colors.blueAccent,
                  ),
                  onPressed: () {
                    setState(() {
                      _isEditing = !_isEditing;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 6),
            Text(
              'HatchTech User',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined,
                        color: Colors.blueAccent),
                    title: const Text('Email'),
                    subtitle: Text(
                      '${_nameController.text.toLowerCase().replaceAll(' ', '')}@hatchtech.com',
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.devices,
                        color: Colors.blueAccent),
                    title: const Text('Manage Incubators'),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => IncubatorManager(
                          incubatorData: widget.incubatorData,
                          onDelete: (name) {
                            if (widget.incubatorData.length <= 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "At least one incubator must remain."),
                                ),
                              );
                              return;
                            }
                            widget.incubatorData.remove(name);
                            Navigator.pop(context); 
                            Navigator.pop(context, true); 
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context, _nameController.text.trim());
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Log Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(
                            themeNotifier: widget.themeNotifier,
                          ),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ),
              ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.devices, size: 40, color: Colors.blueAccent),
          const SizedBox(height: 12),
          const Text(
            'Your Incubators',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            itemCount: incubatorData.keys.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final name = incubatorData.keys.elementAt(index);
              return ListTile(
                title: Text(name),
                trailing: const Icon(Icons.delete_outline,
                    size: 20, color: Colors.blueAccent),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Delete "$name"?'),
                      content: const Text(
                          'Are you sure you want to remove this incubator?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent),
                          onPressed: () {
                            onDelete(name);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
