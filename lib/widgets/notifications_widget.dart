import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationPromptWidget extends StatefulWidget {
  const NotificationPromptWidget({super.key});

  @override
  State<NotificationPromptWidget> createState() => _NotificationPromptWidgetState();
}

class _NotificationPromptWidgetState extends State<NotificationPromptWidget> {
  bool _notificationsEnabled = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserNotificationPreference();
  }

  Future<void> _fetchUserNotificationPreference() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('User').doc(userId).get();
        if (doc.exists && mounted) {
          setState(() {
            _notificationsEnabled = doc.data()?['notificationsEnabled'] ?? false;
          });
        }
      } catch (e) {
        debugPrint('Error fetching notification preferences: $e');
      }
    }
  }

  Future<void> _updateNotificationPreference(bool value) async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _notificationsEnabled = value;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance.collection('User').doc(userId).update({
          'notificationsEnabled': value,
        });

        // Request FCM token only if enabling notifications
        if (value) {
          await _requestFCMToken(userId);
        }
      }
    } catch (e) {
      debugPrint('Error updating notification preference: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _requestFCMToken(String userId) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Check notification settings first
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get token only if permissions granted
        final token = await messaging.getToken();
        if (token != null) {
          // Save token to Firestore
          await FirebaseFirestore.instance.collection('User').doc(userId).update({
            'fcmToken': token,
            'tokenUpdatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('FCM Token saved successfully');
        }
      }
    } catch (e) {
      debugPrint('Error requesting FCM token: $e');
    }
  }

  Future<void> _handleEnableNotifications() async {
    // First update the preference in Firestore
    await _updateNotificationPreference(true);

    // Request notification permission directly through Firebase Messaging
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();

    // If permission is denied or not determined, open app settings
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      // Check if we can open app settings
      if (await openAppSettings()) {
        debugPrint('App settings opened successfully');
      } else {
        debugPrint('Could not open app settings');
      }
    }

    // Close the dialog
    if (mounted && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enable Notifications'),
      content: const Text('Would you like to receive notifications about your meal plan and recipe recommendations?'),
      actions: [
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          TextButton(
            onPressed: () async {
              await _updateNotificationPreference(false);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('No, thanks'),
          ),
          ElevatedButton(
            onPressed: _handleEnableNotifications,
            child: const Text('Yes, enable'),
          ),
        ],
      ],
    );
  }
}