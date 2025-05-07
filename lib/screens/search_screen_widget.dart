import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:reciperealm/widgets/recipe_card.dart';
import '../database/app_repo.dart';
import '../database/entities.dart';
import '../main.dart';

// Κλάση Debouncer για καθυστέρηση αναζήτησης
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void call(Function callback) {
    _timer?.cancel();
    _timer = Timer(delay, () => callback());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({Key? key}) : super(key: key);

  @override
  _SearchResultsScreenState createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer();
  String _searchTerm = '';
  String _debouncedSearchTerm = '';

  bool _isCheckingInternet = true;
  bool _hasInternet = false;
  bool _isLoadingRecipes = true;
  List<RecipeEntity> _localRecipes = [];
  bool _isLoadingLocal = true;
  Future<List<RecipeEntity>>? _localSearchFuture;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allRecipes = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredRecipes = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _recipesSub;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _subscribeRecipesStream();
    _loadLocalRecipes();
  }

  Future<void> _loadLocalRecipes() async {
    final repo = Provider.of<AppRepository>(context, listen: false);
    final recipes = await repo.getRecipes();
    if (!mounted) return;
    setState(() {
      _localRecipes = recipes;
      _isLoadingLocal = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _recipesSub?.cancel();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _checkInternetConnection() async {
    setState(() => _isCheckingInternet = true);
    bool connected;
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 5));
      connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      connected = false;
    }
    setState(() {
      _hasInternet = connected;
      _isCheckingInternet = false;
    });
  }

  void _subscribeRecipesStream() {
    _recipesSub = FirebaseFirestore.instance
        .collection('Recipe')
        .snapshots()
        .listen((snap) {
      setState(() {
        _allRecipes = snap.docs;
        _filterOnlineRecipes();
        _isLoadingRecipes = false;
      });
    }, onError: (err) {
      setState(() => _isLoadingRecipes = false);
    });
  }

  // Μέθοδος για φιλτράρισμα online συνταγών
  void _filterOnlineRecipes() {
    final uid = _currentUser?.uid;

    if (_debouncedSearchTerm.isEmpty) {
      _filteredRecipes = [];
      return;
    }

    _filteredRecipes = _allRecipes.where((doc) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final access = (data['access'] ?? '').toString();
      final createdBy = (data['createdBy'] ?? '').toString();
      return name.contains(_debouncedSearchTerm) &&
          (access == 'public' || createdBy == uid);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final repo = Provider.of<AppRepository>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search recipes by name…',
            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
            border: InputBorder.none,
            suffixIcon: _searchTerm.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, color: isDark ? Colors.white : Colors.black54),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchTerm = '';
                  _debouncedSearchTerm = '';
                  _filterOnlineRecipes();
                });
              },
            )
                : null,
          ),
          onChanged: (value) {
            setState(() => _searchTerm = value.trim().toLowerCase());
            _debouncer(() {
              setState(() {
                _debouncedSearchTerm = _searchTerm;
                _filterOnlineRecipes();
                _localSearchFuture = repo.localDb.recipeDao.searchRecipes(_debouncedSearchTerm);
              });
            });
          },
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    // Check if still loading connection status
    if (_isCheckingInternet) {
      return const Center(child: CircularProgressIndicator());
    }

    // Handle empty search term (initial state)
    if (_debouncedSearchTerm.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Start typing to search recipes',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Handle offline search
    if (!_hasInternet) {
      return _buildOfflineSearchResults();
    }

    // Handle online search
    if (_isLoadingRecipes) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredRecipes.isEmpty) {
      return Center(
        child: Text(
          'No recipes found for "$_debouncedSearchTerm"',
          style: TextStyle(color: Colors.grey, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredRecipes.length,
      itemBuilder: (context, i) {
        final doc = _filteredRecipes[i];
        final data = doc.data();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: RecipeCard(
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
          ),
        );
      },
    );
  }

  // Μέθοδος για offline αναζήτηση με FutureBuilder
  // Μέθοδος για offline αναζήτηση με FutureBuilder
  Widget _buildOfflineSearchResults() {
    // Αν δεν έχουμε αναζήτηση, επιστρέφουμε μήνυμα
    if (_debouncedSearchTerm.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Start typing to search recipes',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<RecipeEntity>>(
      future: _localSearchFuture, // <-- Εδώ
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error searching recipes: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final hits = snapshot.data ?? [];
        if (hits.isEmpty) {
          return Center(
            child: Text(
              'No local recipes found for "$_debouncedSearchTerm"',
              style: const TextStyle(color: Colors.grey, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: hits.length,
          itemBuilder: (context, i) {
            final r = hits[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: RecipeCard(
                documentId: r.documentId,
                name: r.name,
                imageUrl: r.assetPath,
                prepTime: r.prepTime,
                servings: r.servings,
                Introduction: r.Introduction,
                category: r.category,
                difficulty: r.difficulty,
                ingredientsAmount: r.ingredientsAmount,
                ingredients: r.ingredients,
                instructions: r.instructions,
              ),
            );
          },
        );
      },
    );
  }

}