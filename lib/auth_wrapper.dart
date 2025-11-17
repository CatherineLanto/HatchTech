import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'main_navigation.dart';
import 'services/fcm_service.dart';

class AuthWrapper extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeNotifier;

  const AuthWrapper({super.key, required this.themeNotifier});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _currentUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;

        if (user != null) {
          _handleUserLogin(user);

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              final userData = userSnapshot.data!.data() as Map?;
              final username = userData?['username'] ?? 'User';

              final incubators = userData?['incubators'] ?? [];
              final bool hasIncubators = incubators.isNotEmpty;

              return MainNavigation(
                userName: username,
                themeNotifier: widget.themeNotifier,
                hasIncubators: hasIncubators,
              );
            },
          );
        }

        _currentUserId = null;
        return LoginScreen(themeNotifier: widget.themeNotifier);
      },
    );
  }

  void _handleUserLogin(User user) {
    if (_currentUserId != user.uid) {
      _currentUserId = user.uid;
      FcmService.updateTokenForCurrentUser(user);
    }
  }
}