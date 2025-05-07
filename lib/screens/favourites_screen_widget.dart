import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:reciperealm/widgets/recipe_card.dart';
import 'package:reciperealm/database/app_repo.dart';

import '../database/FirebaseDebugUtil.dart';
import '../database/entities.dart';
import 'allrecipes_screen_widget.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<String>> _favoriteIdsFuture;
  bool _isLoading = false;
  late StreamSubscription _connSub;
  bool _isConnected = true;
  bool _hasShownOfflineSnackbar = false;

  @override
  void initState() {
    super.initState();
    // 1) αρχικός έλεγχος
    _checkConnection();
    // 2) ακρόαση αλλαγών
    _connSub = Connectivity()
        .onConnectivityChanged
        .listen((status) {
      final nowOnline = status != ConnectivityResult.none;
      if (nowOnline != _isConnected) {
        setState(() => _isConnected = nowOnline);
        if (!nowOnline && !_hasShownOfflineSnackbar) {
          _hasShownOfflineSnackbar = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline: showing only saved favorites'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      // κατά περίπτωση ξαναφορτώνουμε
      _loadFavorites();
    });
    _loadFavorites();
  }

  Future<void> _checkConnection() async {
    final status = await Connectivity().checkConnectivity();
    if (!mounted) return; // ✅ προστασία
    setState(() => _isConnected = status != ConnectivityResult.none);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when dependencies change (like coming back to this screen)
    _loadFavorites();
  }

  void _loadFavorites() {
    setState(() {
      _isLoading = true;
      FirebaseDebugUtil.debugFirebaseCollections(context);
      _favoriteIdsFuture = _getFavoriteRecipeIds();
    });
  }

  @override
  void dispose() {
    _connSub.cancel();
    super.dispose();
  }

  Future<List<String>> _getFavoriteRecipeIds() async {
    final repo = Provider.of<AppRepository>(context, listen: false);
    // πάντα από local DB
    final localFavs = await repo.getFavorites();
    final ids = localFavs.map((f) => f.documentId).toList();

    // όταν είμαστε online, μπορούμε προαιρετικά να πάρουμε και από Firestore
    if (_isConnected && ids.isEmpty && FirebaseAuth.instance.currentUser != null) {
      final remote = await _getDirectFirestoreFavorites();
      if (remote.isNotEmpty) {
        await repo.syncFavorites();
        return remote;
      }
    }
    return ids;
  }

  Future<List<String>> _getDirectFirestoreFavorites() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    try {
      // Debug: Check if the User collection exists and print all collection names
      debugPrint('[FavoritesScreen] Checking collections in Firestore');
      final collections = await FirebaseFirestore.instance.collection('User').get();
      debugPrint('[FavoritesScreen] User collection exists with ${collections.docs.length} documents');

      final userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(currentUser.uid)
          .get();

      // Debug: Print raw document data
      debugPrint('[FavoritesScreen] Raw user document data: ${userDoc.data()}');

      if (!userDoc.exists) {
        debugPrint('[FavoritesScreen] User document does not exist for ${currentUser.uid}');
        return [];
      }

      final data = userDoc.data();
      if (data == null) return [];

      // Debug: Check what's in the favorites field
      debugPrint('[FavoritesScreen] Favorites field type: ${data['favorites']?.runtimeType}');
      debugPrint('[FavoritesScreen] Favorites field value: ${data['favorites']}');

      if (!data.containsKey('favorites') || data['favorites'] == null) {
        debugPrint('[FavoritesScreen] No favorites field in document');
        return [];
      }

      final favorites = data['favorites'];
      List<String> ids = [];

      if (favorites is List) {
        ids = favorites.map((item) => item.toString()).toList();
      }

      debugPrint('[FavoritesScreen] Direct Firestore favorites: $ids');
      return ids;
    } catch (e) {
      debugPrint('[FavoritesScreen] Error in direct Firestore lookup: $e');
      return [];
    }
  }

  Widget _buildEmptyFavoritesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No favorite recipes yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Start adding your favorite recipes by tapping the heart icon on any recipe',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllRecipesScreen()),
              ).then((_) {
                // refresh after returning
                _loadFavorites();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Explore Recipes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final repo = Provider.of<AppRepository>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorite Recipes'),
        backgroundColor: Colors.green,
      ),
      body: user == null
      // Αν δεν έχει user, φαίνεται empty view
          ? _buildEmptyFavoritesView()
          : FutureBuilder<bool>(
        future: Connectivity().checkConnectivity()
            .then((status) => status != ConnectivityResult.none),

        builder: (ctx, connSnap) {
          if (connSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final isOnline = connSnap.data == true;
          if (!isOnline) {
            // --- OFFLINE:  μόνο  local DB ---
              // Μέσα στο build() του FavoritesScreen, εκεί όπου σήμερα έχεις:
            return FutureBuilder<List<RecipeEntity>>(
              future: repo.localDb.recipeDao.findFavoriteRecipes(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final favs = snap.data ?? [];
                if (favs.isEmpty) return _buildEmptyFavoritesView();
                final recipesData = favs.map((r) => RecipeData(
                  documentId: r.documentId,
                  name: r.name,
                  imageUrl: r.assetPath,
                  prepTime: r.prepTime,
                  servings: r.servings,
                  introduction: r.Introduction,
                  category: r.category,
                  difficulty: r.difficulty,
                  ingredientsAmount: r.ingredientsAmount,
                  ingredients: r.ingredients,
                  instructions: r.instructions,
                )).toList();
                return _buildResponsiveGridView(context, recipesData);
              },
            );
          } else {
            // --- ONLINE:  Firestore stream   ---
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('User')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                final favorites = List<String>.from(data['favorites'] ?? []);
                if (favorites.isEmpty) return _buildEmptyFavoritesView();

                // χωρίζουμε σε chunks των 10 docIds
                final chunks = <List<String>>[];
                for (var i = 0; i < favorites.length; i += 10) {
                  final end = i + 10 < favorites.length ? i + 10 : favorites.length;
                  chunks.add(favorites.sublist(i, end));
                }
                return FavoritesGridView(chunks: chunks);
              },
            );
          }
        },
      ),
    );
  }
}

// A data class to standardize recipe information
class RecipeData {
  final String documentId;
  final String name;
  final String imageUrl;
  final String prepTime;
  final String servings;
  final String introduction;
  final String category;
  final String difficulty;
  final String ingredientsAmount;
  final List<String> ingredients;
  final List<String> instructions;

  RecipeData({
    required this.documentId,
    required this.name,
    required this.imageUrl,
    required this.prepTime,
    required this.servings,
    required this.introduction,
    required this.category,
    required this.difficulty,
    required this.ingredientsAmount,
    required this.ingredients,
    required this.instructions,
  });
}

// A reusable function to build the grid view - UPDATED for better landscape handling
Widget _buildResponsiveGridView(BuildContext context, List<RecipeData> recipes) {
  final orientation = MediaQuery.of(context).orientation;
  final size = MediaQuery.of(context).size;

  // Calculate the optimal number of columns based on screen size
  int crossAxisCount;
  double childAspectRatio;
  double horizontalPadding;

  if (orientation == Orientation.portrait) {
    crossAxisCount = size.width > 600 ? 3 : 2;
    childAspectRatio = 0.7; // Matching AllRecipesScreen ratio for portrait
    horizontalPadding = 12.0;
  } else {
    crossAxisCount = size.width > 600 ? 3 : 2;
    childAspectRatio = 1.2; // Matching AllRecipesScreen ratio for landscape
    horizontalPadding = 16.0;
  }

  return Padding(
    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
    child: GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: recipes.length,
      itemBuilder: (ctx, i) {
        final recipe = recipes[i];
        return RecipeCard(
          documentId: recipe.documentId,
          name: recipe.name,
          imageUrl: recipe.imageUrl,
          prepTime: recipe.prepTime,
          servings: recipe.servings,
          Introduction: recipe.introduction,
          category: recipe.category,
          difficulty: recipe.difficulty,
          ingredientsAmount: recipe.ingredientsAmount,
          ingredients: recipe.ingredients,
          instructions: recipe.instructions,
        );
      },
    ),
  );
}

class FavoritesGridView extends StatelessWidget {
  final List<List<String>> chunks;
  const FavoritesGridView({Key? key, required this.chunks}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPrint('[FavoritesGridView] Building grid with ${chunks.length} chunks: $chunks');

    return FutureBuilder<List<QuerySnapshot>>(
      future: Future.wait(
        chunks.map((chunk) {
          debugPrint('[FavoritesGridView] Querying Recipe collection with chunk: $chunk');
          return FirebaseFirestore.instance
              .collection('Recipe')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
        }),
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('[FavoritesGridView] Error loading recipes: ${snap.error}');
          return Center(child: Text('Error loading recipes: ${snap.error}'));
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snap.data!.expand((qs) => qs.docs).toList();
        debugPrint('[FavoritesGridView] Retrieved ${allDocs.length} recipe documents');

        if (allDocs.isEmpty) {
          debugPrint('[FavoritesGridView] No recipe documents found for favorite IDs');
          return _buildEmptyFavoritesView(context);
        }

        final recipes = allDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return RecipeData(
            documentId: doc.id,
            name: data['name'] ?? 'No Name',
            imageUrl: data['image'] ?? '',
            prepTime: data['prepTime'] ?? '',
            servings: data['servings'] ?? '',
            introduction: data['Introduction'] ?? '',
            category: data['category'] ?? '',
            difficulty: data['difficulty'] ?? '',
            ingredientsAmount: data['ingredientsAmount'] ?? '',
            ingredients: List<String>.from(data['ingredients'] ?? []),
            instructions: List<String>.from(data['instructions'] ?? []),
          );
        }).toList();

        return _buildResponsiveGridView(context, recipes);
      },
    );
  }

  Widget _buildEmptyFavoritesView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Favorite Recipes Found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'We found your favorites but couldn\'t retrieve the recipes',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllRecipesScreen()),
              ).then((_) {
                // This will rebuild the parent widget
                Provider.of<AppRepository>(context, listen: false)
                    .notifyFavoritesChanged();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Explore Recipes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}