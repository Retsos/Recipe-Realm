import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:reciperealm/widgets/recipe_card.dart';
import 'package:reciperealm/screens/login_register_widget.dart';
import 'package:reciperealm/screens/allrecipes_screen_widget.dart';
import 'package:reciperealm/screens/search_screen_widget.dart';
import 'package:reciperealm/screens/myaccount_screen_widget.dart';
import 'package:reciperealm/database/app_repo.dart';
import '../database/entities.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onMealPlanPressed;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const HomeScreen({
    Key? key,
    required this.onMealPlanPressed,
    required this.isDarkMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<RecipeWithFavorite>> _recipesFuture;
  User? get _currentUser => FirebaseAuth.instance.currentUser;
  late StreamSubscription<void> _favSub;

  @override
  void initState(){
    super.initState();
    updateFcmToken();

    final repo = Provider.of<AppRepository>(context, listen: false);
    _recipesFuture = _getRecipesWithFavorites(repo);

    _favSub = repo.favoritesChanged.listen((_) {
      // **ΠΡΟΣΘΗΚΗ**: έλεγξε αν το State είναι ακόμα mounted
      if (!mounted) return;
      setState(() {
        _recipesFuture = _getRecipesWithFavorites(repo);
      });
    });
  }


  Future<List<RecipeWithFavorite>> _getRecipesWithFavorites(AppRepository repo) async {
    // First try to get recipes from local database
    final localRecipes = await repo.getRecipes();
    final localFavs = await repo.getFavorites();
    final favSet = localFavs.map((f) => f.documentId).toSet();

    // Combine recipes with their favorite status
    final combined = localRecipes
        .map((r) => RecipeWithFavorite(r, favSet.contains(r.documentId)))
        .toList();

    // If user is logged in and we want to include remote recipes as well
    // we could add that logic here
    if (_currentUser != null) {
      try {
        // Fetch remote recipes and merge with local
        final remoteRecipes = await _getRemoteRecipes();

        // Add any remote recipes that don't exist locally
        final localIds = combined.map((r) => r.recipe.documentId).toSet();
        for (var remote in remoteRecipes) {
          if (!localIds.contains(remote.recipe.documentId)) {
            combined.add(remote);
          }
        }
      } catch (e) {
        print('Error fetching remote recipes: $e');
        // Continue with local recipes on error
      }
    }

    return combined;
  }

  // If you do want remote, make sure to fix / remove Filter.or(...) as it's not supported in Flutter.
  Future<List<RecipeWithFavorite>> _getRemoteRecipes() async {
    final uid = _currentUser?.uid;
    if (uid == null) {
      print('User is not authenticated.');
      return [];
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('Recipe')
          .where('createdBy', isEqualTo: uid)
          .get();

      if (snap.docs.isEmpty) {
        print('No recipes found for the user.');
      } else {
        print('Recipes fetched: ${snap.docs.length}');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(uid)
          .get();
      final userFavs = (userDoc.data()?['favorites'] as List<dynamic>?)
          ?.cast<String>() ??
          [];

      return snap.docs.map((doc) {
        final d = doc.data();
        return RecipeWithFavorite(
          RecipeEntity(
            documentId:      doc.id,
            name:            d['name'] ?? '',
            assetPath:       d['image'] ?? '',
            imageUrl:        null,
            prepTime:        d['prepTime'] ?? '',
            servings:        d['servings'] ?? '',
            Introduction:    d['Introduction'] ?? '',
            category:        d['category'] ?? '',
            difficulty:      d['difficulty'] ?? '',
            ingredientsAmount: d['ingredientsAmount'] ?? '',
            ingredients:     List<String>.from(d['ingredients'] ?? []),
            instructions:    List<String>.from(d['instructions'] ?? []),
          ),
          userFavs.contains(doc.id),
        );
      }).toList();
    } catch (e) {
      print('Error fetching recipes: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 2,
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  colors: [Colors.orange, Colors.redAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds);
              },
              child: const Icon(
                Icons.restaurant,
                size: 28,
                color: Colors.white, // Required for ShaderMask
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Recipe Realm',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                shadows: const [
                  Shadow(
                    offset: Offset(1, 2),
                    blurRadius: 3.0,
                    color: Colors.black38,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [_buildUserAvatar()],
      ),

      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
            if (isPortrait) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSearchBar(theme),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      width: double.infinity,
                      child: Image.asset('assets/image.png', fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 20),
                    const Text('Recipes', style: TextStyle(fontSize: 24)),
                    const SizedBox(height: 20),

                    FutureBuilder<List<RecipeWithFavorite>>(
                      future: _recipesFuture,
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(child: Text('Error: ${snap.error}'));
                        }
                        final list = snap.data ?? [];
                        if (list.isEmpty) {
                          return const Center(child: Text('No recipes found.'));
                        }

                        final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
                        final visibleItems = list.length > 3 ? 4 : list.length;

                        return SizedBox(
                          height: isPortrait ? 280 : 500,
                          child: GridView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isPortrait ? 1 : 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: visibleItems,
                            itemBuilder: (context, i) {
                              if (i == 3 && list.length > 3) {
                                return _buildSeeAllRecipesCard(widget.isDarkMode);
                              }

                              final rf = list[i];
                              return RecipeCard(
                                documentId: rf.recipe.documentId,
                                name: rf.recipe.name,
                                imageUrl: rf.recipe.assetPath,
                                prepTime: rf.recipe.prepTime,
                                servings: rf.recipe.servings,
                                Introduction: rf.recipe.Introduction,
                                category: rf.recipe.category,
                                difficulty: rf.recipe.difficulty,
                                ingredientsAmount: rf.recipe.ingredientsAmount,
                                ingredients: rf.recipe.ingredients,
                                instructions: rf.recipe.instructions,
                              );
                            },
                          ),
                        );
                      },
                    ),
                    _buildCreateMealPlan(context),
                  ],
                ),
              );
            } else {
              return Row(
                children: [
                  // ── LEFT PANEL ── (Now with SingleChildScrollView)
                  Flexible(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSearchBar(theme),
                            const SizedBox(height: 16),

                            // Image container with fixed dimensions
                            Container(
                              height: 220,
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/image.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            _buildCreateMealPlan(context),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── RIGHT PANEL ──
                  Flexible(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recipes', style: TextStyle(fontSize: 24)),
                          const SizedBox(height: 12),
                          Expanded(
                            child: FutureBuilder<List<RecipeWithFavorite>>(
                              future: _recipesFuture,
                              builder: (ctx, snap) {
                                if (snap.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (snap.hasError) {
                                  return Center(child: Text('Error: ${snap.error}'));
                                }
                                final list = snap.data ?? [];
                                if (list.isEmpty) {
                                  return const Center(child: Text('No recipes found.'));
                                }

                                final visibleItems = list.length > 5 ? 6 : list.length;

                                return GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 1.1,
                                  ),
                                  itemCount: visibleItems,
                                  itemBuilder: (context, i) {
                                    if (i == 5 && list.length > 5) {
                                      return _buildSeeAllRecipesCard(widget.isDarkMode);
                                    }

                                    final rf = list[i];
                                    return RecipeCard(
                                      documentId: rf.recipe.documentId,
                                      name: rf.recipe.name,
                                      imageUrl: rf.recipe.assetPath,
                                      prepTime: rf.recipe.prepTime,
                                      servings: rf.recipe.servings,
                                      Introduction: rf.recipe.Introduction,
                                      category: rf.recipe.category,
                                      difficulty: rf.recipe.difficulty,
                                      ingredientsAmount: rf.recipe.ingredientsAmount,
                                      ingredients: rf.recipe.ingredients,
                                      instructions: rf.recipe.instructions,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;
        final isLoggedIn = user != null;
        final fbKey = ValueKey(isLoggedIn ? user!.uid : 'guest');

        return FutureBuilder<String>(
          key: fbKey,
          future: isLoggedIn
              ? _fetchUserNameFromFirestore(user!.uid)
              : Future.value('Guest'),
          builder: (ctx, snap) {
            String displayName;
            switch (snap.connectionState) {
              case ConnectionState.waiting:
                displayName = isLoggedIn ? 'Loading…' : 'Guest';
                break;
              case ConnectionState.done:
                if (snap.hasError) {
                  displayName = 'User';
                } else {
                  displayName = snap.data ?? 'User';
                }
                break;
              default:
                displayName = 'Guest';
            }

            return Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      displayName,
                      style: TextStyle(
                        color: Colors.green[500],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: IconButton(
                      icon: const Icon(Icons.person),
                      iconSize: 35,
                      color: Colors.green[500],
                      padding: EdgeInsets.zero,
                      onPressed: isLoggedIn ? _navigateToMyAccount : _navigateToLogin,
                    ),
                  ),
                ],
              ),
            );          },
        );
      },
    );
  }

  Future<String> _fetchUserNameFromFirestore(String uid) async {
    final docRef = FirebaseFirestore.instance.collection('User').doc(uid);
    try {
      final snap = await docRef.get();
      return (snap.data()?['name'] as String?) ?? 'User';
    } catch (_) {
      // Fall back to cache
      final cacheSnap = await docRef.get(const GetOptions(source: Source.cache));
      return (cacheSnap.data()?['name'] as String?) ?? 'User';
    }
  }


  Widget _buildSearchBar(ThemeData theme) => Padding(
    padding: const EdgeInsets.all(18),
    child: GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchResultsScreen()),
      ),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.surface.lighten()
              : theme.colorScheme.surface.darken(),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.green[500]),
            const SizedBox(width: 10),
            Text(
              'Find Recipes...',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withAlpha(180),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildSeeAllRecipesCard(bool isDark) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllRecipesScreen()),
    ),
    child: Container(
      width: 250,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.green[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Expanded(
            child: Center(
              child: Text(
                'See all recipes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.black45 : Colors.green[300],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child:  Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('See more',
                    style: TextStyle(
                        color: isDark? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: isDark? Colors.white : Colors.black87),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildCreateMealPlan(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    final fontSize = isPortrait ? 16.0 : 13.0;

    return GestureDetector(
      onTap: widget.onMealPlanPressed,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? Colors.black26 : Colors.green[400],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Create your own meal plan',
              style: TextStyle(
                fontSize: fontSize, // Δυναμικό font size
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode ? Colors.white : Colors.grey[800],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: isPortrait ? 16 : 13,
                color: widget.isDarkMode ? Colors.green : Colors.white),
          ],
        ),
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
    );
  }

  void _navigateToMyAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyAccountPage(
          isDarkMode: widget.isDarkMode,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );
  }

  Future<void> updateFcmToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('User').doc(uid).update({
          'fcmToken': token,
        });
      }
    }
  }}

class RecipeWithFavorite {
  final RecipeEntity recipe;
  final bool isFavorite;
  RecipeWithFavorite(this.recipe, this.isFavorite);
}
extension ColorBrightness on Color {
  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness(
        (hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }

  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }


}