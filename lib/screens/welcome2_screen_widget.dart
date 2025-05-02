import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:reciperealm/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Welcome2Screen extends StatefulWidget {

  const Welcome2Screen({
    Key? key,
  }) : super(key: key);

  @override
  _Welcome2ScreenState createState() => _Welcome2ScreenState();
}

class _Welcome2ScreenState extends State<Welcome2Screen> {
  late String userName;


  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    userName = user?.displayName ?? 'User'; // Fallback to 'User' if null
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Welcome to Recipe Realm",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF1B5E20),
              Color(0xFF2E7D32),
              Color(0xFF388E3C),
              Color(0xFF43A047),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Διακοσμητικά στοιχεία
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Εικονίδια διακόσμησης
            Positioned(
              top: 120,
              right: 30,
              child: Icon(
                Icons.restaurant,
                size: 40,
                color: Colors.white.withAlpha(30),
              ),
            ),
            Positioned(
              bottom: 150,
              left: 30,
              child: Icon(
                Icons.kitchen,
                size: 40,
                color: Colors.white.withAlpha(30),
              ),
            ),
            // Κύριο περιεχόμενο
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Λογότυπο εφαρμογής
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(50),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        size: 48,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Κείμενο καλωσορίσματος με το όνομα χρήστη
                    _buildWelcomeText(),
                    const SizedBox(height: 30),
                    // Tagline
                    _buildTagline(),
                    const SizedBox(height: 30),
                    // Περιγραφή
                    _buildDescription(),
                    const SizedBox(height: 60),
                    // Κουμπί ολοκλήρωσης onboarding
                    // Inside Welcome2Screen (onboarding completion)
                    ElevatedButton(
                      onPressed: () async {
                        // 1. Clear the onboarding-needed flag (user has finished onboarding)
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('needs_onboarding', false);

                        // 2. Navigate to the main app layout, replacing the onboarding route
                        Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) =>  MainLayout(
                              isDarkMode: false, // Or get from provider
                              onThemeChanged: (value) {}, // Or connect to your provider
                              ),
                            ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 40,
                        ),
                        backgroundColor: Colors.amber[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                      ),
                      child: Text('Start Cooking'),

                    ),

                    const SizedBox(height: 16),
                    // Δευτερεύον κουμπί για τα quick tips
                    FloatingActionButton(
                      onPressed: () {
                        _showQuickTips(context);
                      },
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2E7D32),
                      child: const Icon(Icons.help_outline),
                    ),
                    const Spacer(),
                    // Footer κείμενο
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Text(
                        "Powered by Recipe Realm",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              blurRadius: 10.0,
              color: Colors.black26,
              offset: Offset(2.0, 2.0),
            ),
          ],
        ),
        children: [
          const TextSpan(text: "Hello, "),
          TextSpan(
            text:userName,
            style: const TextStyle(
              color: Colors.amber,
              decorationColor: Colors.white,
              decorationThickness: 2,
            ),
          ),
          const TextSpan(text: "! 👋"),
        ],
      ),
    );
  }

  // Tagline κείμενο
  Widget _buildTagline() {
    return const Text(
      "Your culinary adventure begins here!",
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 24,
        color: Colors.white,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        shadows: [
          Shadow(
            blurRadius: 6.0,
            color: Colors.black26,
            offset: Offset(2.0, 2.0),
          ),
        ],
      ),
    );
  }

  // Περιγραφή
  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30), width: 1),
      ),
      child: const Text(
        "Discover recipes and create new ones, save your favorites, "
            "and make meal plans that suit your lifestyle. "
            "Let's cook something amazing!",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          height: 1.5,
          color: Colors.white,
          fontWeight: FontWeight.w400,
          shadows: [
            Shadow(
              blurRadius: 4.0,
              color: Colors.black26,
              offset: Offset(1.0, 1.0),
            ),
          ],
        ),
      ),
    );
  }

  // Εμφάνιση quick tips σε διάλογο
  void _showQuickTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Quick Tips",
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ListTile(
                  leading: Icon(Icons.search, color: Color(0xFF2E7D32)),
                  title: Text("Search recipes and create your own!"),
                  subtitle: Text("Find dishes based on your appetite"),
                ),
                ListTile(
                  leading: Icon(Icons.favorite, color: Colors.red),
                  title: Text("Save favorites"),
                  subtitle: Text("Keep track of recipes you love"),
                ),
                ListTile(
                  leading: Icon(Icons.calendar_today, color: Colors.amber),
                  title: Text("Plan your meals"),
                  subtitle: Text("Organize your weekly cooking schedule"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Got it!"),
            ),
          ],
        );
      },
    );
  }
}
