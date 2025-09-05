import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'main_navigation.dart';
import 'services/auth_service.dart';

class AuthWrapper extends StatelessWidget {
  final ValueNotifier<ThemeMode> themeNotifier;

  const AuthWrapper({super.key, required this.themeNotifier});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // If user is logged in
        if (snapshot.hasData) {
          return StreamBuilder<Map<String, dynamic>?>(
            stream: AuthService.getUserDataStream(),
            builder: (context, userDataSnapshot) {
              if (userDataSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              final username = userDataSnapshot.data?['username'] ?? 'User';
              return MainNavigation(
                userName: username,
                themeNotifier: themeNotifier,
              );
            },
          );
        }
        
        // If user is not logged in
        return LoginScreen(themeNotifier: themeNotifier);
      },
    );
  }
}
