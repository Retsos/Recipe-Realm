import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reciperealm/screens/about_screen_widget.dart';
import 'package:reciperealm/screens/myaccount_screen_widget.dart';

import '../database/app_repo.dart';
import '../database/entities.dart';
import '../main.dart';
import 'myrecipes_screen_widget.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback onFavoritePressed;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.onFavoritePressed,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {

    final themeProvider = Provider.of<ThemeProvider>(context);
    final repository = Provider.of<AppRepository>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        children: [
          // My Account
          ListTile(
            leading: const Icon(Icons.account_circle, color: Colors.green),
            title: const Text("My Account"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyAccountPage(
                    isDarkMode: themeProvider.isDarkMode,
                    onThemeChanged: (value) {
                      // Update the provider
                      themeProvider.toggleDarkMode(value);
                      // Save to database
                      repository.updateSetting(
                        UserSettingEntity.darkTheme(value),
                      );
                      // Also call the passed function
                      onThemeChanged(value);
                    },                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.green),
            title: const Text("My Favorites"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onFavoritePressed,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.food_bank, color: Colors.green),
            title: const Text("My Recipes"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyRecipesScreen()),
              );
            },          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.green),
            title: const Text("Language"),
            trailing: Text(
              "English",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
            ),
          ),
          const Divider(),
          // About.
          ListTile(
            leading: const Icon(Icons.info, color: Colors.green),
            title: const Text("About"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
          ),
          const Divider(),
          // ListTile(
          //   leading: Icon(
          //       themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          //       color: Colors.green
          //   ),
          //   title: const Text("Dark Mode"),
          //   trailing: Switch(
          //     value: themeProvider.isDarkMode,
          //     onChanged: (newValue) {
          //       // Update the provider (which now also saves to database)
          //       themeProvider.toggleDarkMode(newValue);
          //
          //       // Also call the passed function to ensure MainLayout is updated
          //       onThemeChanged(newValue);
          //     },
          //     activeColor: Colors.green[500],
          //   ),
          // ),
          // const Divider(),
        ],
      ),
    );
  }
}
