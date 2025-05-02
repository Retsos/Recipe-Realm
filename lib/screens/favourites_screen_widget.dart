import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:reciperealm/widgets/recipe_card.dart';
import 'package:reciperealm/database/app_repo.dart';

import '../database/FirebaseDebugUtil.dart';
import 'allrecipes_screen_widget.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<String>> _favoriteIdsFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Kick off the first load
    _loadFavorites();
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

  Future<List<String>> _getFavoriteRecipeIds() async {
    try {
      final repo = Provider.of<AppRepository>(context, listen: false);

      // Always use the repository's getFavorites method first
      final favorites = await repo.getFavorites();
      final ids = favorites.map((fav) => fav.documentId).toList();

      debugPrint('[FavoritesScreen] Found ${ids.length} favorites: $ids');

      // If we have no favorites and user is signed in, try a direct Firestore fetch as backup
      if (ids.isEmpty && FirebaseAuth.instance.currentUser != null) {
        debugPrint('[FavoritesScreen] No favorites found in repository, trying direct Firestore lookup');
        final directIds = await _getDirectFirestoreFavorites();

        // If we found favorites directly, trigger a sync to update the repository
        if (directIds.isNotEmpty) {
          debugPrint('[FavoritesScreen] Found ${directIds.length} favorites directly from Firestore');
          // Use public method instead of private method
          await repo.syncFavorites();
          return directIds;
        }
      }

      setState(() {
        _isLoading = false;
      });
      return ids;
    } catch (e) {
      debugPrint('[FavoritesScreen] Error fetching favorites: $e');
      setState(() {
        _isLoading = false;
      });
      return [];
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorite Recipes'),
        backgroundColor: Colors.green,
      ),
      body: user == null
          ? _buildEmptyFavoritesView()
          : StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('User')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildEmptyFavoritesView();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?
              ?? {};
          final favorites = List<String>.from(data['favorites'] ?? []);

          if (favorites.isEmpty) {
            return _buildEmptyFavoritesView();
          }

          final chunks = <List<String>>[];
          for (var i = 0; i < favorites.length; i += 10) {
            final end = (i + 10 < favorites.length) ? i + 10 : favorites.length;
            chunks.add(favorites.sublist(i, end));
          }

          return FavoritesGridView(chunks: chunks);
        },
      ),
    );
  }
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

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.7,
          ),
          itemCount: allDocs.length,
          itemBuilder: (ctx, i) {
            final doc = allDocs[i];
            final data = doc.data() as Map<String, dynamic>;
            debugPrint('[FavoritesGridView] Rendering recipe card for ${doc.id}: ${data['name']}');
            return RecipeCard(
              documentId: doc.id,
              name: data['name'] ?? 'No Name',
              imageUrl: data['image'] ?? '',
              prepTime: data['prepTime'] ?? '',
              servings: data['servings'] ?? '',
              Introduction: data['Introduction'] ?? '',
              category: data['category'] ?? '',
              difficulty: data['difficulty'] ?? '',
              ingredientsAmount: data['ingredientsAmount'] ?? '',
              ingredients: List<String>.from(data['ingredients'] ?? []),
              instructions: List<String>.from(data['instructions'] ?? []),
            );
          },
        );
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