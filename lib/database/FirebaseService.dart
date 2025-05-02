// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_repo.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppRepository _repository;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  FirebaseService(this._repository);

  // Check if user is authenticated
  bool get isUserAuthenticated => _auth.currentUser != null;


  // Get all recipes with access control
  Future<List<Map<String, dynamic>>> getAllRecipes() async {
    try {
      final snap = await _firestore.collection('Recipe').get();

      // Convert to a list of maps that contain both recipe data and metadata
      final allRecipes = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'documentId': doc.id,
          'name': data['name'] ?? '',
          'assetPath': '',
          'imageUrl': data['image'] ?? '',
          'prepTime': data['prepTime'] ?? '',
          'servings': data['servings'] ?? '',
          'Introduction': data['Introduction'] ?? '',
          'category': data['category'] ?? '',
          'difficulty': data['difficulty'] ?? '',
          'ingredientsAmount': data['ingredientsAmount'] ?? '',
          'ingredients': List<String>.from(data['ingredients'] ?? []),
          'instructions': List<String>.from(data['instructions'] ?? []),
          'metadata': {
            'createdBy': data['createdBy'] ?? '',
            'access': data['access'] ?? 'public',
            'isOwnRecipe': data['createdBy'] == currentUserId && data['createdBy'] != '',
            'isDefaultRecipe': data['createdBy'] == null || data['createdBy'] == '',
          }
        };
      }).toList();

      // Filter recipes based on access permissions
      final accessibleRecipes = allRecipes.where((recipe) {
        final metadata = recipe['metadata'] as Map<String, dynamic>;

        // Default recipes
        if (metadata['isDefaultRecipe'] == true) {
          return true;
        }

        // Recipes created by current user
        if (metadata['isOwnRecipe'] == true) {
          return true;
        }

        // Public recipes from other users
        if (metadata['access'] == 'public') {
          return true;
        }

        // Otherwise, don't show (private recipes from other users)
        return false;
      }).toList();

      debugPrint('Loaded ${accessibleRecipes.length} accessible recipes from Firestore');
      return accessibleRecipes;
    } catch (e) {
      debugPrint('Error loading recipes from Firestore: $e');
      return [];
    }
  }
  Future<List<Map<String, dynamic>>> getLocalDefaultRecipes() async {
    final localRecipes = await _repository.getRecipes(); // RecipeEntity list
    return localRecipes.map((r) => {
      'documentId': r.documentId,
      'name': r.name,
      'assetPath': r.assetPath,
      'prepTime': r.prepTime,
      'servings': r.servings,
      'Introduction': r.Introduction,
      'category': r.category,
      'difficulty': r.difficulty,
      'ingredientsAmount': r.ingredientsAmount,
      'ingredients': r.ingredients,
      'instructions': r.instructions,
      'imageUrl': null,
      'metadata': {
        'createdBy': '',
        'access': 'public',
        'isOwnRecipe': false,
        'isDefaultRecipe': true,
      }
    }).toList();
  }

  // Get a single recipe by ID
  Future<Map<String, dynamic>?> getRecipeById(String documentId) async {
    try {
      final doc = await _firestore.collection('Recipe').doc(documentId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;

      // Check access permissions
      final createdBy = data['createdBy'] ?? '';
      final access = data['access'] ?? 'public';

      // Default recipe or own recipe or public recipe
      if (createdBy == '' || createdBy == currentUserId || access == 'public') {
        return {
          'documentId': doc.id,
          'name': data['name'] ?? '',
          'assetPath': '',
          'imageUrl': data['image'] ?? '',
          'prepTime': data['prepTime'] ?? '',
          'servings': data['servings'] ?? '',
          'Introduction': data['Introduction'] ?? '',
          'category': data['category'] ?? '',
          'difficulty': data['difficulty'] ?? '',
          'ingredientsAmount': data['ingredientsAmount'] ?? '',
          'ingredients': List<String>.from(data['ingredients'] ?? []),
          'instructions': List<String>.from(data['instructions'] ?? []),
          'metadata': {
            'createdBy': createdBy,
            'access': access,
            'isOwnRecipe': createdBy == currentUserId && createdBy != '',
            'isDefaultRecipe': createdBy == '',
          }
        };
      }

      // Private recipe from another user
      return null;
    } catch (e) {
      debugPrint('Error getting recipe by ID: $e');
      return null;
    }
  }

  // Add new recipe
  Future<String?> addRecipe(Map<String, dynamic> recipeData) async {
    try {
      // Ensure user is authenticated
      if (!isUserAuthenticated) {
        throw Exception('User not authenticated');
      }

      // Add createdBy field
      recipeData['createdBy'] = currentUserId;

      // Set default access to public if not specified
      if (!recipeData.containsKey('access')) {
        recipeData['access'] = 'public';
      }

      final docRef = await _firestore.collection('Recipe').add(recipeData);
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding recipe: $e');
      return null;
    }
  }

  // Update recipe
  Future<bool> updateRecipe(String documentId, Map<String, dynamic> recipeData) async {
    try {
      // Check if user can edit this recipe
      final doc = await _firestore.collection('Recipe').doc(documentId).get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data()!;
      final createdBy = data['createdBy'] ?? '';

      // Only allow editing if it's a user's own recipe
      if (createdBy != currentUserId) {
        return false;
      }

      // Update the recipe
      await _firestore.collection('Recipe').doc(documentId).update(recipeData);
      return true;
    } catch (e) {
      debugPrint('Error updating recipe: $e');
      return false;
    }
  }

  // Delete recipe
  Future<bool> deleteRecipe(String documentId) async {
    try {
      // Check if user can delete this recipe
      final doc = await _firestore.collection('Recipe').doc(documentId).get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data()!;
      final createdBy = data['createdBy'] ?? '';

      // Only allow deletion if it's a user's own recipe
      if (createdBy != currentUserId) {
        return false;
      }

      // Delete the recipe
      await _firestore.collection('Recipe').doc(documentId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
      return false;
    }
  }
}
