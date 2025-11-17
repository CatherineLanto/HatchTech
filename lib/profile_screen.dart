// ignore_for_file: avoid_print

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/invite_service.dart';
import 'user_management_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, Map<String, dynamic>> incubatorData;
  final String selectedIncubator;
  final ValueNotifier<ThemeMode> themeNotifier;
  final String userName;
  final VoidCallback? onUserNameChanged;

  const ProfileScreen({
    super.key,
    required this.incubatorData,
    required this.selectedIncubator,
    required this.themeNotifier,
    required this.userName,
    this.onUserNameChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _newAvatarFile;
  String? _avatarUrl;
  late TextEditingController _nameController;
  bool _isEditing = false;
  bool _isLoading = false;
  String originalLoginName = '';
  String userEmail = '';
  String? userRole;
  String? generatedInviteCode;
  String? selectedInviteRole;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _loadFirebaseUserData();
  }

  Future<void> _loadFirebaseUserData() async {
    try {
      final userData = await AuthService.getUserData();
      if (userData != null && mounted) {
        setState(() {
          originalLoginName = userData['username'] ?? widget.userName;
          userEmail = userData['email'] ?? '';
          userRole = userData['role'] ?? '';
          _nameController.text = originalLoginName;
          _avatarUrl = userData['avatarUrl'] as String?;
        });
      }
    } catch (e) {
      setState(() {
        originalLoginName = widget.userName;
        userEmail = AuthService.currentUser?.email ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveUserData() async {
    if (_newAvatarFile != null) {
      final userId = AuthService.currentUser?.uid;
      if (userId != null) {
        final ref = FirebaseStorage.instance.ref().child('avatars/$userId.jpg');
        await ref.putFile(_newAvatarFile!);
        final url = await ref.getDownloadURL();
        await FirebaseFirestore.instance.collection('users').doc(userId).update({'avatarUrl': url});
        setState(() {
          _avatarUrl = url;
          _newAvatarFile = null;
        });
      }
    }
    if (!_isEditing) return;

    setState(() {
      _isLoading = true;
    });

    final newUsername = _nameController.text.trim();
    bool usernameChanged = newUsername != originalLoginName;
    if (usernameChanged && newUsername.isNotEmpty) {
      final result = await AuthService.updateUserProfile(
        username: newUsername,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success']) {
          setState(() {
            originalLoginName = newUsername;
            _isEditing = false;
          });

          widget.onUserNameChanged?.call();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      setState(() {
        _isLoading = false;
        _isEditing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.themeNotifier.value == ThemeMode.dark;
    final roleLower = (userRole ?? '').toLowerCase();
    bool isOwnerOrAdmin = roleLower.contains('owner') || roleLower.contains('admin');
    bool isManager = roleLower.contains('manager');

    final currentUserId = AuthService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await _saveUserData();
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
            Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: isDark ? const Color(0xFF6BB6FF) : Colors.blueAccent,
                    backgroundImage: _newAvatarFile != null
                        ? FileImage(_newAvatarFile!)
                        : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null) as ImageProvider?,
                    child: (_newAvatarFile == null && _avatarUrl == null)
                        ? const Icon(Icons.person, size: 60, color: Colors.white)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () async {
                          final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setState(() {
                            _newAvatarFile = File(picked.path);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.edit, color: Colors.blueAccent, size: 24),
                      ),
                    ),
                  ),
                  if (_newAvatarFile != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _newAvatarFile = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.close, color: Colors.red, size: 24),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              GestureDetector(
                onTap: () {
                  if (!_isEditing) {
                    setState(() {
                      _isEditing = true;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isEditing 
                      ? (isDark ? Colors.grey[800] : Colors.grey[100])
                      : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: _isEditing 
                    ? Border.all(
                        color: isDark ? const Color(0xFF6BB6FF) : Colors.blueAccent,
                        width: 1,
                      )
                    : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          enabled: _isEditing,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Tap to edit username',
                            hintStyle: TextStyle(fontSize: 18),
                          ),
                          onSubmitted: (_) async {
                            await _saveUserData();
                          },
                        ),
                      ),
                      if (_isEditing) ...[
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _nameController.text = originalLoginName;
                              _isEditing = false;
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.check,
                            color: isDark ? const Color(0xFF6BB6FF) : Colors.blueAccent,
                            size: 20,
                          ),
                          onPressed: () async {
                            await _saveUserData();
                          },
                        ),
                      ] else ...[
                        Icon(
                          Icons.edit,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),

              const SizedBox(height: 10),

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
                    if (isOwnerOrAdmin && currentUserId != null) ...[
                      ListTile(
                        leading: Icon(Icons.group,
                            color: isDark ? const Color(0xFF6BB6FF) : Colors.blueAccent),
                        title: const Text('User Management'),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (_) => SizedBox(
                              height: MediaQuery.of(context).size.height * 0.85,
                              child: UserManagementScreen(ownerUid: currentUserId),
                            ),
                            );
                        },
                      ),
                      const Divider(height: 0),
                    ],
                    if ((isOwnerOrAdmin || isManager))
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
                              onDelete: (name) async {
                                await FirebaseFirestore.instance.collection('incubators').doc(name).delete();
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

              const SizedBox(height: 10),
              if (isOwnerOrAdmin) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final currentUser = FirebaseAuth.instance.currentUser;

                      if (currentUser != null) {
                        final newCode = await InviteService.createInviteCode(
                          "User",
                          currentUser.uid,
                        );

                        setState(() {
                          generatedInviteCode = newCode;
                        });

                        print("Generated invite code: $newCode");
                      } else {
                        print("⚠️ No user is currently logged in.");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Generate Invite Code', style: TextStyle(fontSize: 16)),
                  ),
                ),
                if (generatedInviteCode != null) ...[
                  const SizedBox(height: 12),
                  const Text('Invite Code:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SelectableText(generatedInviteCode!, style: const TextStyle(fontSize: 20, color: Colors.blueAccent)),
                ],
                const SizedBox(height: 10),
              ],
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
                    await _saveUserData();
                    await AuthService.signOut();
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
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
    final incubatorNames = incubatorData.keys.toList();
    final double maxListHeight = MediaQuery.of(context).size.height * 0.4; 

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 40), 
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

          if (incubatorNames.isEmpty)
            const Text(
              'No incubators currently assigned for management.',
              textAlign: TextAlign.center,
              style: TextStyle(fontStyle: FontStyle.italic),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxListHeight),
              child: ListView.separated(
                shrinkWrap: true, 
                itemCount: incubatorNames.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final name = incubatorNames.elementAt(index);
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
                              'Are you sure you want to remove this incubator? This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red), 
                              onPressed: () {
                                onDelete(name);
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
            ),
        ],
      ),
    );
  }
}