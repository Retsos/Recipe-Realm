import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Αφαιρούμε το AppBar και χρησιμοποιούμε Stack για να βάλουμε το βελάκι πάνω στην εικόνα
      body: Column(
        children: [
          // Πάνω μέρος με εικόνα και κουμπί επιστροφής
          Stack(
            children: [
              // Η εικόνα καλύπτει το πάνω μέρος
              Image.asset(
                'assets/image.png',
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              ),
              // Το κουμπί επιστροφής πάνω αριστερά
              Positioned(
                top: 40, // για να μην κολλάει στην κορυφή (ανάλογα με το status bar)
                left: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),

          // Κείμενο περιγραφής εφαρμογής
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Recipe Realm",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "The Recipe Realm app was created in the context of a university course,"
                        " with the goal of providing a modern and easy-to-use experience for discovering, storing and managing recipes."
                        "Users can organize their meals, create their own recipes and enjoy the cooking process in an interactive way.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
