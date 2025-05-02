import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../screens/welcome_screen_widget.dart';
import 'guest_provider_widget.dart';

class AuthWrapper extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const AuthWrapper({
    Key? key,
    required this.isDarkMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final guestProvider = Provider.of<GuestProvider>(context);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Guest mode check
        if (guestProvider.isGuest) {
          return MainLayout(
            isDarkMode: isDarkMode,
            onThemeChanged: onThemeChanged,
          );
        }

        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;

          // If logged in, go to main layout
          return MainLayout(
            isDarkMode: isDarkMode,
            onThemeChanged: onThemeChanged,
          );
        }

        // Loading state
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}