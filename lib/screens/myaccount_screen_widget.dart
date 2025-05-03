import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reciperealm/widgets/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:reciperealm/main.dart';
import '../database/app_repo.dart';
import '../database/entities.dart';

class MyAccountPage extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const MyAccountPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<MyAccountPage> createState() => _MyAccountPageState();
}

class _MyAccountPageState extends State<MyAccountPage> {
  bool _isLoading = true;
  UserProfileEntity? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      // 1️⃣ get your repo
      final repo = Provider.of<AppRepository>(context, listen: false);

      // 2️⃣ get the auth user
      final firebase_auth.User? user = firebase_auth.FirebaseAuth.instance.currentUser;

      if (user != null) {
        // 3️⃣ attempt to load cached profile
        var profile = await repo.getLocalProfile();
        debugPrint('Loaded local profile: $profile');

        // 4️⃣ if missing or empty name, pull from Firestore
        if (profile == null || profile.name.trim().isEmpty) {
          debugPrint('No local name found, fetching from Firestore…');
          final doc = await FirebaseFirestore.instance.collection('User').doc(user.uid).get();
          final cloudName = (doc.data()?['name'] as String?) ?? '';
          profile = UserProfileEntity(
            uid: user.uid,
            name: cloudName,
            email: user.email ?? '',
          );
          // 5️⃣ save the freshly-fetched profile locally
          await repo.saveLocalProfile(profile);
          debugPrint('Saved profile locally: $profile');
        }

        _userProfile = profile;
      } else {
        _userProfile = null;
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      _userProfile = null;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  // Loading widget.
  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
      ),
    );
  }


  // Build profile header
  Widget _buildProfileHeader(String? photoUrl, String name, String email, ThemeData theme) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
              ? NetworkImage(photoUrl)
              : null,
          child: (photoUrl == null || photoUrl.isEmpty)
              ? Icon(Icons.person, size: 50, color: Colors.green[700])
              : null,
        ),
      ],
    );
  }

  // Build account details section
  Widget _buildAccountDetailsSection(String name, String email, DateTime? createdAt, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Account Details",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(height: 30),
            _buildDetailItem(Icons.person, "Name", name, theme),
            _buildDetailItem(Icons.email, "Email", email, theme),
            if (createdAt != null)
              _buildDetailItem(
                Icons.calendar_today,
                "Member Since",
                "${createdAt.toLocal().toString().split(' ')[0]}",
                theme,
              ),
          ],
        ),
      ),
    );
  }

  // Helper function for each detail item
  Widget _buildDetailItem(IconData icon, String title, String value, ThemeData theme) {
    return ListTile(
      leading: Icon(icon, color: Colors.green[500]),
      title: Text(
        title,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(value, style: theme.textTheme.bodyLarge),
      contentPadding: EdgeInsets.zero,
    );
  }

  // Build app settings section using Provider
  Widget _buildAppSettingsSection(ThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final repository = Provider.of<AppRepository>(context, listen: false);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "App Settings",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(height: 30),
            ListTile(
              leading: Icon(Icons.dark_mode, color: Colors.green[500]),
              title: const Text("Dark Mode"),
              trailing: Switch(
                value: themeProvider.isDarkMode,
                onChanged: (newValue) {
                  themeProvider.toggleDarkMode(newValue);
                  repository.updateSetting(
                    UserSettingEntity.darkTheme(newValue),
                  );

                  // Also call the passed function
                  widget.onThemeChanged(newValue);
                },
                activeColor: Colors.green[500],
                activeTrackColor: Colors.grey[700],
                inactiveThumbColor: Colors.grey[800],
                inactiveTrackColor: Colors.green[100],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build logout button
  Widget _buildLogoutButton(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text("Log Out"),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode ? Colors.redAccent : Colors.red[900],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () async {
          try {
            await AuthService.logout(context);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Logout failed: ${e.toString()}"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("My Account"),
          backgroundColor: Colors.green[500],
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              children: [
                _buildProfileHeader(null, "Not logged in", "-", theme),
                const SizedBox(height: 30),
                _buildAccountDetailsSection("Not logged in", "Please sign in to view details", null, theme),
                const SizedBox(height: 30),
                _buildAppSettingsSection(theme),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("My Account"),
          backgroundColor: Colors.green[500],
          elevation: 0,
        ),
        body: _buildLoadingWidget(),
      );
    }

    final String name = _userProfile?.name ?? user.displayName ?? "User";
    final String email = _userProfile?.email ?? user.email ?? "-";
    final DateTime? createdAt = null;
    final String? photoUrl = user.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Account"),
        backgroundColor: Colors.green[500],
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: isLandscape
                ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildProfileHeader(photoUrl, name, email, theme),
                      const SizedBox(height: 30),
                      _buildLogoutButton(context),
                    ],
                  ),
                ),
                const SizedBox(width: 30),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildAccountDetailsSection(name, email, createdAt, theme),
                      const SizedBox(height: 30),
                      _buildAppSettingsSection(theme),
                    ],
                  ),
                ),
              ],
            )
                : Column(
              children: [
                _buildProfileHeader(photoUrl, name, email, theme),
                const SizedBox(height: 30),
                _buildAccountDetailsSection(name, email, createdAt, theme),
                const SizedBox(height: 30),
                _buildAppSettingsSection(theme),
                const SizedBox(height: 30),
                _buildLogoutButton(context),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

}