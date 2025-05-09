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
    return localRecipes.map((r) {
      final asset = r.assetPath.startsWith('assets/')
          ? r.assetPath
          : 'assets/${r.assetPath}';
      return {
        'documentId': r.documentId,
        'name':        r.name,
        'assetPath':   asset,
        'prepTime':    r.prepTime,
        'servings':    r.servings,
        'Introduction':r.Introduction,
        'category':    r.category,
        'difficulty':  r.difficulty,
        'ingredientsAmount': r.ingredientsAmount,
        'ingredients': r.ingredients,
        'instructions':r.instructions,
        'imageUrl':    null,
        'metadata': {
          'createdBy':     '',
          'access':        'public',
          'isOwnRecipe':   false,
          'isDefaultRecipe': true,
        },
      };
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

  ///ΣΥΝΤΑΓΕΣ ΓΙΑ ΣΥΓΚΕΚΡΙΜΕΝΗ ΚΑΤΗΓΟΡΙΑ ΜΕ IS EQUAL TO
  Future<List<Map<String,dynamic>>> getRecipesByCategory(String category) async {
    try {
      final snap = await _firestore
          .collection('Recipe')
          .withConverter<Map<String,dynamic>>(
        fromFirestore: (s, _) => s.data()!,
        toFirestore:   (m, _) => m,
      )
          .where('category', isEqualTo: category)
          .get();

      return snap.docs.map(docToMap).toList();
    } catch (e) {
      debugPrint('Error fetching recipes by category: $e');
      return [];
    }
  }

  ///ΣΥΝΤΑΓΕΣ ΕΝΌΣ ΧΡΗΣΤΗ ΜΕ CREATED BY
  Future<List<Map<String,dynamic>>> getRecipesByUser(String userId) async {
    try {
      final snap = await _firestore
          .collection('Recipe')
          .withConverter<Map<String,dynamic>>(
        fromFirestore: (s, _) => s.data()!,
        toFirestore:   (m, _) => m,
      )
          .where('createdBy', isEqualTo: userId)
          .get();

      return snap.docs.map(docToMap).toList();
    } catch (e) {
      debugPrint('Error fetching recipes by user: $e');
      return [];
    }
  }


  ///ΣΥΝΤΑΓΕΣ ΓΙΑ ΣΥΓΚΕΚΡΙΜΕΝΕΣ ΜΕΡΙΔΕΣ ΜΕ Numeric Range Query
  Future<List<Map<String, dynamic>>> getRecipesByServingsRange(String servingsFilter) async {
    try {
      // 1. Parse filter range
      int filterMin;
      int? filterMax;

      if (servingsFilter.endsWith('+')) {
        filterMin = int.parse(servingsFilter.replaceAll('+', ''));
        filterMax = null; // no upper bound
      } else if (servingsFilter.contains('-')) {
        final parts = servingsFilter.split('-');
        filterMin = int.parse(parts[0]);
        filterMax = int.parse(parts[1]);
      } else {
        filterMin = int.parse(servingsFilter);
        filterMax = filterMin;
      }

      // 2. Fetch all recipes
      final snap = await _firestore
          .collection('Recipe')
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data()!,
        toFirestore: (m, _) => m,
      )
          .get();

      // 3. Filter so that the recipe range lies entirely within το filter range
      final allRecipes = snap.docs.map(docToMap).toList();
      final results = allRecipes.where((recipe) {
        final servingsStr = recipe['servings'].toString().trim();
        int recipeMin, recipeMax;

        if (servingsStr.contains('-')) {
          final p = servingsStr.split('-');
          recipeMin = int.tryParse(p[0].trim()) ?? 0;
          recipeMax = int.tryParse(p[1].trim()) ?? recipeMin;
        } else {
          recipeMin = int.tryParse(servingsStr) ?? 0;
          recipeMax = recipeMin;
        }

        if (filterMax == null) {
          // case "4+"
          return recipeMin >= filterMin;
        } else {
          // case "X-Y" or exact
          return recipeMin >= filterMin && recipeMax <= filterMax;
        }
      }).toList();

      debugPrint('[DEBUG] Found ${results.length} recipes with servings: $servingsFilter');
      return results;
    } catch (e) {
      debugPrint('Error fetching recipes by servings: $e');
      return [];
    }
  }

  Map<String, dynamic> docToMap(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    String servingsStr = '';
    final servingsData = data['servings'] ?? '';

    if (servingsData is int) {
      servingsStr = servingsData.toString();
    } else if (servingsData is String) {
      servingsStr = servingsData;
    }

    return {
      'documentId': doc.id,
      'name': data['name'] ?? '',
      'assetPath': '',
      'imageUrl': data['image'] ?? '',
      'prepTime': data['prepTime'] ?? '',
      'servings': servingsStr,
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
      },
    };
  }

  /// Φέρνει τις συνταγές εφαρμόζοντας category, servingsRange και onlyMy στο Firestore
  Future<List<Map<String, dynamic>>> getRecipes({
    String? category,
    String? servingsRange,
    bool onlyMy = false,
  }) async {
    try {

      Query<Map<String, dynamic>> query =
      _firestore.collection('Recipe').withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data()!,
        toFirestore: (map, _) => map,
      );

      final isGuest = !isUserAuthenticated;

      // 2) Αν  guest, mono default
      if (isGuest) {
        query = query
            .where('createdBy', isEqualTo: '');
      }

      // 2) Φίλτρο "μόνο δικές μου"
      if (onlyMy && currentUserId != null) {
        query = query.where('createdBy', isEqualTo: currentUserId);
      }

      // 3) Φίλτρο κατηγορίας
      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }


      final snap = await query.get();
      var recs = snap.docs.map(docToMap).toList();

      if (servingsRange != null) {
        recs = recs.where((r) {
          final s = r['servings'].toString().trim();
          return _matchesServingsFilter(s, servingsRange);
        }).toList();
      }

      return recs;
    } catch (e) {
      debugPrint('Error getRecipes with filters: $e');
      return [];
    }
  }

  // Βοηθητική για range τύπου "2-4" ή "4+"
  bool _matchesServingsFilter(String s, String filter) {
    if (filter.endsWith('+')) {
      final min = int.tryParse(filter.replaceAll('+','')) ?? 0;
      final val = int.tryParse(s.split('-').first) ?? 0;
      return val >= min;
    }
    if (filter.contains('-')) {
      final parts = filter.split('-').map((t)=>int.tryParse(t)??0).toList();
      final min = parts[0], max = parts[1];
      final recParts = s.contains('-')
          ? s.split('-').map((t)=>int.tryParse(t)??0).toList()
          : [int.tryParse(s)??0];
      final rmin = recParts[0], rmax = recParts.length>1 ? recParts[1] : rmin;
      return rmin>=min && rmax<=max;
    }
    return s == filter;
  }
}