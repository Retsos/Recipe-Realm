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
  Future<void> _showDeleteConfirmation(
      BuildContext context, String recipeId, String recipeName) async {
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
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Deleting recipe...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                final success = await _deleteRecipe(recipeId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Recipe "$recipeName" deleted'
                          : 'Failed to delete recipe.'),
                      backgroundColor: success ? Colors.green : Colors.red,
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

  Future<bool> _deleteRecipe(String recipeId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      await FirebaseFirestore.instance.collection('Recipe').doc(recipeId).delete();
      await FirebaseFirestore.instance
          .collection('User')
          .doc(user.uid)
          .update({
        'myrecipes': FieldValue.arrayRemove([recipeId]),
        'favorites': FieldValue.arrayRemove([recipeId]),
      });
      return true;
    } catch (e) {
      debugPrint('Deletion error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
        );
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
          final crossAxisCount = MediaQuery.of(context).size.width > 600 ? (isLandscape ? 3 : 2) : 1;
          final childAspectRatio = isLandscape ? 1.4 : 0.85;

          return SafeArea(child: GridView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewPadding.bottom + 96,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return FullWidthRecipeCard(
                documentId: doc.id,
                name: data['name'] ?? '',
                imageUrl: data['image'] ?? '',
                prepTime: data['prepTime'] ?? '',
                servings: data['servings'] ?? '',
                Introduction: data['Introduction'] ?? '',
                category: data['category'] ?? '',
                difficulty: data['difficulty'] ?? '',
                ingredientsAmount: data['ingredientsAmount'] ?? '',
                ingredients: List<String>.from(data['ingredients'] ?? []),
                instructions: List<String>.from(data['instructions'] ?? []),
                isFavorite: false, // option to load favorites if needed
                onFavoritePressed: (bool _) {},
                onDeletePressed: () {
                  _showDeleteConfirmation(context, doc.id, data['name'] ?? '');
                },
              );
            },
              )
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateRecipeScreen()),
        ),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No Recipes Created Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Share your culinary creations with the world by adding your first recipe',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateRecipeScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Create New Recipe', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
            ),
        ),
    );
  }
}
