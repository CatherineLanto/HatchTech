import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String originalLoginName = '';
  String userEmail = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _loadOriginalLoginName();
  }

  Future<void> _loadOriginalLoginName() async {
    final prefs = await SharedPreferences.getInstance();
    // Get the current user key from the system
    final currentUser = prefs.getString('current_user') ?? '';
    
    if (currentUser.isNotEmpty) {
      final original = prefs.getString('original_login_name_$currentUser');
      final email = prefs.getString('user_email_$currentUser');
      
      if (original != null && original.isNotEmpty) {
        setState(() {
          originalLoginName = original;
          userEmail = email ?? '${original.toLowerCase().replaceAll(' ', '')}@hatchtech.com';
        });
        return;
      }
    }
    
    // Fallback: if no current_user or no original_login_name found, 
    // try using the current username as key (for backward compatibility)
    final userKey = widget.userName.toLowerCase().replaceAll(' ', '');
    final original = prefs.getString('original_login_name_$userKey');
    final email = prefs.getString('user_email_$userKey');
    
    if (original != null && original.isNotEmpty) {
      setState(() {
        originalLoginName = original;
        userEmail = email ?? '${original.toLowerCase().replaceAll(' ', '')}@hatchtech.com';
      });
    } else {
      // Last fallback: use the widget.userName as original
      setState(() {
        originalLoginName = widget.userName;
        userEmail = '${widget.userName.toLowerCase().replaceAll(' ', '')}@hatchtech.com';
      });
    }
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
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Auto-save and return username if changed
            await _saveUserData();
            // ignore: use_build_context_synchronously
            Navigator.pop(context, _nameController.text.trim());
          },
        ),
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
            CircleAvatar(
              radius: 60,
              backgroundColor: isDark ? const Color(0xFF6BB6FF) : Colors.blueAccent,
              child: const Icon(
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
                    style: Theme.of(context).textTheme.headlineSmall,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isEditing ? Icons.check_circle : Icons.edit,
                    color: isDark ? const Color(0xFF6BB6FF) : Colors.blueAccent,
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
              originalLoginName.isNotEmpty ? originalLoginName : widget.userName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? const Color(0xFFB0B0B0) : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 30),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.email_outlined,
                        color: isDark ? const Color(0xFF6BB6FF) : Colors.blueAccent),
                    title: const Text('Email'),
                    subtitle: Text(
                      userEmail.isNotEmpty ? userEmail : '${originalLoginName.toLowerCase().replaceAll(' ', '')}@hatchtech.com',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Icon(Icons.devices,
                        color: isDark ? const Color(0xFF6BB6FF) : Colors.blueAccent),
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
                            Navigator.pop(context, _nameController.text.trim()); 
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Just logout button - no save button needed since changes auto-save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF6BB6FF) : Colors.blueAccent,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  // Auto-save any username changes before logging out
                  await _saveUserData();
                  
                  // Clear current user session
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('current_user');
                  
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      // ignore: use_build_context_synchronously
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoginScreen(
                          themeNotifier: widget.themeNotifier,
                        ),
                      ),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Auto-save user data when changes are made
  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = prefs.getString('current_user') ?? '';
    
    if (currentUser.isNotEmpty) {
      // Save username if it was changed
      final newUsername = _nameController.text.trim();
      if (newUsername.isNotEmpty) {
        await prefs.setString('user_name_$currentUser', newUsername);
      }
    }
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
          Text(
            'Your Incubators',
            style: Theme.of(context).textTheme.titleLarge,
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
