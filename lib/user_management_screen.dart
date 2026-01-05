import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';

class UserManagementScreen extends StatelessWidget {
  final String ownerUid;
  const UserManagementScreen({super.key, required this.ownerUid});

  void _showEditUserDialog(BuildContext context, String userId, Map<String, dynamic> user) {
  final usernameController = TextEditingController(text: user['username'] ?? '');
  final emailController = TextEditingController(text: user['email'] ?? '');
  String roleRaw = (user['role'] ?? 'user').toString().toLowerCase();
  String role = roleRaw.contains('owner') || roleRaw.contains('admin') ? 'owner' : 'user';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'owner', child: Text('Owner/Admin')),
                    DropdownMenuItem(value: 'user', child: Text('User')),
                  ],
                  onChanged: (val) {
                    if (val != null) role = val;
                  },
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newUsername = usernameController.text.trim();
                final newEmail = emailController.text.trim();
                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                  'username': newUsername,
                  'role': role,
                });
                if (newEmail != (user['email'] ?? '')) {
                  final result = await AuthService.updateUserEmail(userId: userId, newEmail: newEmail);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: result['success'] ? Colors.green : Colors.red));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User updated.')));
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('users')
          .where('ownerUid', isEqualTo: ownerUid) 
          .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text('Error loading users: ${snapshot.error}'));
          }
          
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
             future: FirebaseFirestore.instance.collection('users').doc(ownerUid).get(),
             builder: (context, ownerSnapshot) {
               
               List<Map<String, dynamic>> usersList = [];
               
               if (ownerSnapshot.hasData && ownerSnapshot.data!.exists) {
                 final ownerData = ownerSnapshot.data!.data()!;
                 usersList.add({
                   ...ownerData,
                   'id': ownerSnapshot.data!.id,
                   'isOwner': true,
                 });
               }

               if (snapshot.hasData) {
                 for (var doc in snapshot.data!.docs) {
                   if (doc.id != ownerUid) { 
                     usersList.add({
                       ...doc.data(),
                       'id': doc.id,
                       'isOwner': false,
                     });
                   }
                 }
               }
               
               if (usersList.isEmpty) {
                 return const Center(child: Text('No users connected yet.'));
               }

               usersList.sort((a, b) {
                  if (a['id'] == ownerUid) return -1;
                  if (b['id'] == ownerUid) return 1;
                  return (a['username'] ?? '').compareTo(b['username'] ?? '');
               });
               
               return ListView.builder(
                 itemCount: usersList.length,
                 itemBuilder: (context, index) {
                   final user = usersList[index];
                   final userId = user['id'] as String;
                   final isCurrentUser = userId == currentUserId;
                   final userRole = (user['role'] ?? 'user').toString();

                   return Card(
                     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     child: ListTile(
                       leading: const Icon(Icons.person),
                       title: Text(
                         user['username'] ?? 'Unknown',
                         style: TextStyle(fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal),
                       ),
                       subtitle: Text(
                         '${user['email'] ?? 'No Email'} - ${userRole[0].toUpperCase()}${userRole.substring(1)}',
                       ),
                       trailing: isCurrentUser
                           ? const Text('You', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))
                           : PopupMenuButton<String>(
                               onSelected: (value) async {
                                 if (value == 'edit') {
                                   _showEditUserDialog(context, userId, user);
                                 } else if (value == 'remove') {
                                   final confirmed = await showDialog<bool>(
                                     context: context,
                                     builder: (ctx) => AlertDialog(
                                       title: const Text('Remove User?'),
                                       content: Text('Are you sure you want to remove ${user['username']} from your team?'),
                                       actions: [
                                         TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                         ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx, true), 
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                            child: const Text('Remove', style: TextStyle(color: Colors.white))
                                         ),
                                       ],
                                     ),
                                   ) ?? false;

                                   if (confirmed) {
                                     await FirebaseFirestore.instance.collection('users').doc(userId).delete();
                                     if (context.mounted) {
                                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User removed.')));
                                     }
                                   }
                                 }
                               },
                               itemBuilder: (context) => [
                                 const PopupMenuItem(value: 'edit', child: Text('Edit Role')),
                                    const PopupMenuItem(value: 'remove', child: Text('Remove User', style: TextStyle(color: Colors.red))),
                               ],
                             ),
                     ),
                   );
                 },
               );
             },
          );
        },
      ),
    );
  }
}