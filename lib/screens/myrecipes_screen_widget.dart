import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reciperealm/screens/login_register_widget.dart';

import '../widgets/recipe_card2_widget.dart';
import 'createrecipe_screen_widget.dart';

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({Key? key}) : super(key: key);

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  // Function to show delete confirmation dialog
  Future<void> _showDeleteConfirmation(BuildContext context, String recipeId, String recipeName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Recipe?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete "$recipeName"?'),
                const SizedBox(height: 10),
                const Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close dialog first

                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Deleting recipe...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                // Delete the recipe from Firestore
                bool success = await _deleteRecipe(recipeId);

                // Show appropriate message based on success
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          success
                              ? 'Recipe "$recipeName" successfully deleted'
                              : 'Failed to delete recipe. Please try again.'
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Function to delete the recipe from Firestore
  Future<bool> _deleteRecipe(String recipeId) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      debugPrint('Starting deletion of recipe: $recipeId');

      // 1. Delete the recipe from the main Recipe collection
      await FirebaseFirestore.instance
          .collection('Recipe')
          .doc(recipeId)
          .delete()
          .then((_) => debugPrint('Successfully deleted recipe from Recipe collection'))
          .catchError((error) {
        debugPrint('Error deleting from Recipe collection: $error');
        throw error; // Re-throw to be caught by the outer try-catch
      });

      // 2. Try to remove this recipe from the user's myrecipes collection if it exists
      try {
        await FirebaseFirestore.instance
            .collection('User')
            .doc(currentUser.uid)
            .update({
          'myrecipes': FieldValue.arrayRemove([recipeId]),
        });

        debugPrint('Successfully deleted from myrecipes subcollection');
      } catch (e) {
        // This might fail if the document doesn't exist, which is okay
        debugPrint('Note: Could not delete from myrecipes (might not exist): $e');
      }

      // 3. Remove this recipe from all users' favorites
      try {
        final usersSnapshot = await FirebaseFirestore.instance.collection('User').get();
        for (var userDoc in usersSnapshot.docs) {
          final userData = userDoc.data();
          final List<String> userFavorites = (userData['favorites'] as List?)?.cast<String>() ?? [];

          if (userFavorites.contains(recipeId)) {
            debugPrint('Removing recipe from favorites for user: ${userDoc.id}');
            await FirebaseFirestore.instance.collection('User').doc(userDoc.id).update({
              'favorites': FieldValue.arrayRemove([recipeId])
            });
          }
        }
      } catch (e) {
        debugPrint('Error updating favorites: $e');
        // We don't want to fail the overall deletion just because of favorites issue
      }

      debugPrint('Recipe deletion completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error in recipe deletion process: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginRegisterPage()),
        );
      });
      return Container();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Recipes'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Recipe')
            .where('createdBy', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Recipes Created Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Share your culinary creations with the world by adding your first recipe',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateRecipeScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'Create New Recipe',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }

          final recipeDocs = snapshot.data!.docs;

          // Changed from GridView to ListView for full width cards
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recipeDocs.length,
            itemBuilder: (context, index) {
              final doc = recipeDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final recipeName = data['name'] ?? 'No Name';

              // Check if the recipe is in user's favorites
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('User')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  bool isFavorite = false;

                  if (userSnapshot.hasData && userSnapshot.data != null) {
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                    final List<String> userFavorites =
                        (userData?['favorites'] as List?)?.cast<String>() ?? [];
                    isFavorite = userFavorites.contains(doc.id);
                  }

                  // Use the FullWidthRecipeCard directly, no need for Stack with Positioned
                  return FullWidthRecipeCard(
                    documentId: doc.id,
                    name: recipeName,
                    imageUrl: data['image'] ?? '',
                    prepTime: data['prepTime'] ?? '',
                    servings: data['servings'] ?? '',
                    Introduction: data['Introduction'] ?? '',
                    category: data['category'] ?? '',
                    difficulty: data['difficulty'] ?? '',
                    ingredientsAmount: data['ingredientsAmount'] ?? '',
                    ingredients: data['ingredients'] != null
                        ? List<String>.from(data['ingredients'] as List<dynamic>)
                        : <String>[],
                    instructions: data['instructions'] != null
                        ? List<String>.from(data['instructions'] as List<dynamic>)
                        : <String>[],
                    isFavorite: isFavorite,
                    onFavoritePressed: (bool newFavStatus) async {
                      final userDocRef =
                      FirebaseFirestore.instance.collection('User').doc(user.uid);
                      if (newFavStatus) {
                        await userDocRef.update({
                          'favorites': FieldValue.arrayUnion([doc.id])
                        });
                      } else {
                        await userDocRef.update({
                          'favorites': FieldValue.arrayRemove([doc.id])
                        });
                      }
                    },
                    onDeletePressed: () {
                      _showDeleteConfirmation(context, doc.id, recipeName);
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateRecipeScreen()),
          );
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}