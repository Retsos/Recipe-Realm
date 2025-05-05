import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationPromptWidget extends StatefulWidget {
  const NotificationPromptWidget({super.key});

  @override
  _NotificationPromptWidgetState createState() => _NotificationPromptWidgetState();
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
      final doc = await FirebaseFirestore.instance.collection('User').doc(userId).get();
      if (doc.exists) {
        setState(() {
          _notificationsEnabled = doc.data()?['notificationsEnabled'] ?? false;
        });
      }
    }
  }

  Future<void> _updateNotificationPreference(bool value) async {
    setState(() {
      _loading = true;
      _notificationsEnabled = value;
    });

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await FirebaseFirestore.instance.collection('User').doc(userId).update({
        'notificationsEnabled': value,
      });
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
    });

  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enable Notifications'),
      content: const Text('Do you want to receive notifications about your meal plan?'),
      actions: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          )
        else ...[
          SizedBox(
            width: 100,
            child: TextButton(
              onPressed: () async {
                if (context.mounted) Navigator.of(context).pop();
                await _updateNotificationPreference(false);
              },
              child: const Text('No'),
            ),
          ),
          SizedBox(
            width: 100,
            child: TextButton(
              onPressed: () async {
                if (context.mounted) Navigator.of(context).pop();
                await _updateNotificationPreference(true);
              },
              child: const Text('Yes'),
            ),
          ),
        ],
      ],
    );
  }
}
