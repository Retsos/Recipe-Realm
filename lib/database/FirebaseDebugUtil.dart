import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirebaseDebugUtil {
  static Future<void> debugFirebaseCollections(BuildContext context) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      final String userId = currentUser?.uid ?? 'Not signed in';

      debugPrint('==== FIREBASE DEBUG ====');
      debugPrint('Current user: $userId');

      // List all collections
      debugPrint('Checking Firebase collections...');
      final collections = await FirebaseFirestore.instance.collection('User').get();
      debugPrint('User collection has ${collections.docs.length} documents');

      // Check user document if signed in
      if (currentUser != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('User')
              .doc(currentUser.uid)
              .get();

          debugPrint('User document exists: ${userDoc.exists}');
          if (userDoc.exists) {
            final data = userDoc.data();
            debugPrint('User document data: $data');

            // Check favorites field
            if (data != null && data.containsKey('favorites')) {
              final favorites = data['favorites'];
              debugPrint('Favorites field type: ${favorites.runtimeType}');
              debugPrint('Favorites content: $favorites');

              if (favorites is List) {
                final favoriteIds = List<String>.from(
                    favorites.map((f) => f.toString()));
                debugPrint('Parsed favorite IDs: $favoriteIds');

                // Try retrieving each recipe
                for (final id in favoriteIds) {
                  try {
                    final recipeDoc = await FirebaseFirestore.instance
                        .collection('Recipe')
                        .doc(id)
                        .get();
                    debugPrint('Recipe $id exists: ${recipeDoc.exists}');
                  } catch (e) {
                    debugPrint('Error checking recipe $id: $e');
                  }
                }
              }
            } else {
              debugPrint('No favorites field in user document');
            }
          }
        } catch (e) {
          debugPrint('Error checking user document: $e');
        }
      }

      // Check Recipe collection
      try {
        final recipeDocs = await FirebaseFirestore.instance
            .collection('Recipe')
            .limit(5)
            .get();
        debugPrint('Recipe collection has documents: ${recipeDocs.docs.isNotEmpty}');
        if (recipeDocs.docs.isNotEmpty) {
          final sampleId = recipeDocs.docs.first.id;
          debugPrint('Sample recipe ID: $sampleId');
        }
      } catch (e) {
        debugPrint('Error checking Recipe collection: $e');
      }

      debugPrint('==== END DEBUG ====');
    } catch (e) {
      debugPrint('Debug utility error: $e');
    }
  }
}