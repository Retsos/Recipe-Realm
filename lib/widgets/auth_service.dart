import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_repo.dart';
import '../database/database_provider.dart';
import '../database/entities.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../main.dart';
import '../screens/welcome_screen_widget.dart';

class AuthService {
  static final FirebaseAuth _auth      = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _didInitNotifications = false;
  static bool didCheckNotificationPrompt = false;

  /// Must be called once (e.g. in main) with your shared repository:
  ///
  /// ```dart
  /// AuthService.configure(repository);
  /// ```
  static late AppRepository _repo;
  static void configure(AppRepository repository) {
    _repo = repository;
  }
  /// Start logging auth state changes to the console.
  static void startAuthLogging() {
    _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        print('User is currently signed out!');
      } else {
        print('User is signed in! User ID: ${user.uid}');
      }
    });
  }

  /// Stream of auth state changes.
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<bool> hasRealInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
  static DateTime? _lastSnackbarTime;

  static void _showErrorSnackbar(String message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    ///ΑΠΟΦΥΓΗ ΣΠΑΜ
    final now = DateTime.now();

    // Αν έχει περάσει λιγότερο από 2.5 δευτερόλ  επτα, δεν δειχνω νέο Snackbar
    if (_lastSnackbarTime != null &&
        now.difference(_lastSnackbarTime!).inMilliseconds < 2500) {
      return;
    }

    _lastSnackbarTime = now;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );

    }
  }

  /// Log in with email and password.
  static Future<User?> login(String email, String password, BuildContext context) async {

    if (!await hasRealInternet()) {
      _showErrorSnackbar('There is no internet connection. Please try again later!');
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_guest_logged_in');

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = cred.user!;
      debugPrint('✅ Login successful: ${user.uid}');

      // 🔁 Ανανεώνεις τη βάση στον DatabaseProvider & στο AppRepository
      await DatabaseProvider.resetInstance();
      await _repo.reinitializeDatabase(); // <== αυτό λέει στο AppRepository να ξαναπάρει το νέο DB instance

      // 🔍 Προαιρετικός έλεγχος DB (για debug)
      //await _safeDatabaseCheck(user);

      // 👤 Φόρτωσε user info από Firestore
      final userDoc = await _firestore.collection('User').doc(user.uid).get();
      final userName = (userDoc.data()?['name'] as String?) ?? '';
      final userEmail = user.email ?? '';

      final profile = UserProfileEntity(
        uid: user.uid,
        name: userName,
        email: userEmail,
      );
      try {
        await _repo.saveLocalProfile(profile);
      } catch (e) {
        debugPrint('⚠️ Skipped local profile save: DB is closed.');
        debugPrint('❌ Error saving profile locally: $e');
      }

      // 🔄 Συγχρονισμός
      await _repo.initializeForUser(user.uid);
      await Future.delayed(const Duration(milliseconds: 100));
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AuthGate(),
        ),
      );
      return user;
    } on FirebaseAuthException catch (e) {
      throw _authError(e.code);
    } catch (e) {
      debugPrint('Unhandled login error: $e');
      rethrow;
    }
  }

  /// Register a new user.
  static Future<User?> register(String name, String email, String password) async {

    if (!await hasRealInternet()) {
      _showErrorSnackbar('There is no internet connection. Please try again later!');
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_guest_logged_in');
    await prefs.setBool('needs_onboarding', true);

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = cred.user!;
      await user.updateDisplayName(name.trim());

      // Create Firestore user doc
      await _firestore.collection('User').doc(user.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'favorites': [],
        'myrecipes': [],
        'createdAt': FieldValue.serverTimestamp(),
        'notificationsEnabled': false,
      });

      // Save locally
      final profile = UserProfileEntity(
        uid:   user.uid,
        name:  name.trim(),
        email: email.trim(),
      );
      await _repo.saveLocalProfile(profile);
      await _repo.initializeForUser(user.uid);

      print('Registration successful for user: $name ($email)');
      await Future.delayed(const Duration(milliseconds: 100));
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AuthGate(),
        ),
      );


      return user;
    } on FirebaseAuthException catch (e) {
      throw _authError(e.code);
    }
  }

  /// Log out the current user.
  static Future<void> logout(BuildContext context) async {
    if (!await hasRealInternet()) {
      _showErrorSnackbar('There is no internet connection. Please try again later');
      return;
    }

    try {
      await _repo.clearUserData();
      await DatabaseProvider.resetInstance();
      await FirebaseMessaging.instance.deleteToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_guest_logged_in');
      await prefs.clear();
      await _auth.signOut();
      _didInitNotifications = false;

    } catch (e) {
      _showErrorSnackbar('Logout error: $e');
    }
  }

  /// Log out and navigate to the login/register page.
  // static Future<void> logoutAndNavigate(BuildContext context) async {
  //   await logout();
  //   if (context.mounted) {
  //     Navigator.pushAndRemoveUntil(
  //       context,
  //       MaterialPageRoute(builder: (_) => const WelcomeScreen()),
  //           (route) => false,
  //     );
  //   }
  // }



  /// Update the current user's favorites list by adding or removing a recipe ID.
  static Future<void> updateUserFavorite(String recipeId, bool add) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final doc = _firestore.collection('User').doc(user.uid);
    if (add) {
      await doc.update({'favorites': FieldValue.arrayUnion([recipeId])});
    } else {
      await doc.update({'favorites': FieldValue.arrayRemove([recipeId])});
    }
  }

  /// Returns the current user.
  static User? getCurrentUser() => _auth.currentUser;

  /// Returns true if a user is logged in.
  static bool isLoggedIn() => _auth.currentUser != null;

  /// Fetch current user's favorites.
  static Future<List<String>> getUserFavorites() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final doc = await _firestore.collection('User').doc(user.uid).get();
      final data = doc.data() ?? {};
      final favs = List<dynamic>.from(data['favorites'] ?? []);
      return favs.map((e) => e.toString()).toList();
    } catch (e) {
      print('Error fetching favorites: $e');
      return [];
    }
  }

  /// Check if a recipe is in user's favorites.
  static Future<bool> isRecipeFavorite(String recipeId) async {
    final favs = await getUserFavorites();
    return favs.contains(recipeId);
  }

  // Helper for mapping FirebaseAuth codes to user-friendly messages.
  static String _authError(String code) {
    switch (code) {
      case 'invalid-email':          return 'Invalid email format';
      case 'user-disabled':          return 'Account disabled';
      case 'user-not-found':         return 'User not found';
      case 'wrong-password':         return 'Incorrect password';
      case 'email-already-in-use':   return 'Email already registered';
      case 'weak-password':          return 'Password too weak';
      case 'network-request-failed': return 'Network error, please check your connection';
      case 'operation-not-allowed':  return 'Operation not allowed';
      case 'too-many-requests':      return 'Too many requests, please try again later';
      case 'user-token-expired':     return 'Session expired, please sign in again';
      default:                       return 'Authentication error';
    }
  }
}
