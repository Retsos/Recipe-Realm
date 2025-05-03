import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:reciperealm/widgets/auth_service.dart';
import 'package:reciperealm/widgets/guest_provider_widget.dart';
import 'package:reciperealm/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoginMode = true;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool needs_onboarding = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Check for internet connectivity
  Future<bool> _checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (_isLoginMode) {
        // For login
        await AuthService.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          context,
        );
        // The AuthWrapper will handle navigation
      } else {
        // First register
        final user = await AuthService.register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (user == null) return; // ❌ Μην προχωρήσεις αν δεν έγινε register

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('needs_onboarding', true);

      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar(e.toString());
      }
    }
  }


  void _showErrorSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _formKey.currentState?.reset();
    });
  }

  Future<void> _continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest_logged_in', true);
    Provider.of<GuestProvider>(context, listen: false).setGuest(true);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => MainLayout(
          isDarkMode: false,
          onThemeChanged: (bool newValue) {
          },
        ),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.green[900]!,
                Colors.green[700]!,
                Colors.green[500]!,
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              // To ensure our content fills all available space if needed
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeaderSection(),
                    const SizedBox(height: 50),
                    _buildAuthCard(),
                    const SizedBox(height: 30),
                    _buildGuestButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        const Text(
          "Recipe Realm",
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                blurRadius: 6.0,
                color: Colors.black54,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Text(
          _isLoginMode ? "Welcome Back!" : "Create Your Account",
          style: const TextStyle(
            fontSize: 22,
            color: Colors.white70,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withAlpha(102),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (!_isLoginMode) _buildNameField(),
              if (!_isLoginMode) const SizedBox(height: 16),
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              if (!_isLoginMode) const SizedBox(height: 16),
              if (!_isLoginMode) _buildConfirmPasswordField(),
              const SizedBox(height: 30),
              _buildSubmitButton(),
              const SizedBox(height: 20),
              _buildToggleAuthButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return _buildInputField(
      controller: _nameController,
      label: "Full Name",
      icon: Icons.person_outline,
      validator: (value) =>
      value?.isEmpty ?? true ? "Please enter your name" : null,
    );
  }

  Widget _buildEmailField() {
    return _buildInputField(
      controller: _emailController,
      label: "Email Address",
      icon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value?.isEmpty ?? true) return "Please enter email";
        if (!RegExp(
            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
            .hasMatch(value!)) {
          return "Invalid email format";
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return _buildInputField(
      controller: _passwordController,
      label: "Password",
      icon: Icons.lock_outline,
      isPassword: true,
      validator: (value) {
        if (value?.isEmpty ?? true) return "Please enter password";
        if (value!.length < 6) return "Minimum 6 characters";
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return _buildInputField(
      controller: _confirmPasswordController,
      label: "Confirm Password",
      icon: Icons.lock_reset,
      isPassword: true,
      validator: (value) {
        if (value?.isEmpty ?? true) return "Please confirm password";
        if (value != _passwordController.text)
          return "Passwords don't match";
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submit,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.green[800],
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
        child: Text(
          _isLoginMode ? "Sign In" : "Sign Up",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleAuthButton() {
    return TextButton(
      onPressed: _toggleMode,
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 18),
          children: [
            TextSpan(
              text: _isLoginMode ? "New here? " : "Already have an account? ",
            ),
            TextSpan(
              text: _isLoginMode ? "Create Account" : "Sign In",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestButton() {
    return ElevatedButton.icon(
      onPressed: _continueAsGuest,
      icon: const Icon(Icons.person_outline, color: Colors.white),
      label: const Text(
        "Continue as Guest",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        padding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(102),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            floatingLabelStyle: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.never,
            alignLabelWithHint: false,
            isDense: false,
            prefixIcon: Icon(icon, color: Colors.green[700]),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 20,
            ),
            errorStyle: const TextStyle(
              fontSize: 15,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}