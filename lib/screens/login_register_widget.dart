import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:reciperealm/widgets/auth_service.dart';
import 'package:reciperealm/screens/home_screen_widget.dart';
import 'package:reciperealm/screens/welcome2_screen_widget.dart';

import '../main.dart';

class LoginRegisterPage extends StatefulWidget {
  const LoginRegisterPage({Key? key}) : super(key: key);

  @override
  State<LoginRegisterPage> createState() => _LoginRegisterPageState();
}

class _LoginRegisterPageState extends State<LoginRegisterPage> {
  bool _isLoginMode = true;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (_isLoginMode) {
        await AuthService.login(_emailController.text.trim(), _passwordController.text.trim(),context);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) {
              // Get the current theme state from provider
              final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
              return HomeScreen(
                onMealPlanPressed: _dummyMealPlanCallback,
                isDarkMode: themeProvider.isDarkMode,
                onThemeChanged: (bool value) {
                  themeProvider.toggleDarkMode(value);
                },
              );

            },
          ),
        );
      } else {
        await AuthService.register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const Welcome2Screen()),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Authentication error"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  static void _dummyMealPlanCallback() {}

  void _toggleMode() {
    setState(() => _isLoginMode = !_isLoginMode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Properly access the theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Get current theme data
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLoginMode ? "Welcome Back" : "Create Account",
          style: TextStyle(
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          // Add theme toggle button
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny : Icons.nightlight_round,
              color: Colors.green[500],
            ),
            onPressed: () => themeProvider.toggleDarkMode(!isDark),
          ),
        ],
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [theme.colorScheme.surface.lighten(), theme.colorScheme.surface]
                : [Colors.green.shade100, Colors.green.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                if (!_isLoginMode)
                  _buildInputField(_nameController, 'Full Name', Icons.person_outline),
                _buildInputField(_emailController, 'Email Address', Icons.email_outlined),
                _buildInputField(_passwordController, 'Password', Icons.lock_outline, isPassword: true),
                if (!_isLoginMode)
                  _buildInputField(_confirmPasswordController, 'Confirm Password', Icons.lock_reset, isPassword: true),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green[500],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_isLoginMode ? 'Sign In' : 'Sign Up'),
                ),
                const SizedBox(height: 25),
                TextButton(
                  onPressed: _toggleMode,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withAlpha(220),
                      ),
                      children: [
                        TextSpan(
                          text: _isLoginMode ? "New to Recipe Realm? " : "Already have an account? ",
                        ),
                        TextSpan(
                          text: _isLoginMode ? "Sign Up" : "Sign In",
                          style: TextStyle(
                            color: Colors.green[500],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.colorScheme.onSurface.withAlpha(180)),
          prefixIcon: Icon(icon, color: Colors.green[500]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isDark
                  ? theme.colorScheme.surface.lighten()
                  : theme.colorScheme.surface.darken(),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Colors.green[500]!,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          filled: true,
          fillColor: isDark
              ? theme.colorScheme.surface.lighten()
              : theme.colorScheme.surface.darken(0.05),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please enter $label';
          if (!_isLoginMode && label == 'Confirm Password' && value != _passwordController.text) return 'Passwords do not match';
          return null;
        },
      ),
    );
  }
}