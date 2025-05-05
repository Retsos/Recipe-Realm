import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:reciperealm/widgets/recipe_card.dart';
import '../main.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({Key? key}) : super(key: key);

  @override
  _SearchResultsScreenState createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  bool _isCheckingInternet = true;
  bool _hasInternet = false;
  bool _isLoadingRecipes = true;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allRecipes = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _recipesSub;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _subscribeRecipesStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _recipesSub?.cancel();
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
        _isLoadingRecipes = false;
      });
    }, onError: (err) {
      // Μπορείτε να χειριστείτε το σφάλμα εδώ
      setState(() => _isLoadingRecipes = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

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
                });
              },
            )
                : null,
          ),
          onChanged: (value) => setState(() => _searchTerm = value.trim().toLowerCase()),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    // 1) Έλεγχος σύνδεσης
    if (_isCheckingInternet) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasInternet) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.signal_wifi_off, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No Internet Connection',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _checkInternetConnection,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // 2) Φόρτωση recipes
    if (_isLoadingRecipes) {
      return const Center(child: CircularProgressIndicator());
    }

    // 3) Όταν δεν έχει γραφτεί τίποτα
    if (_searchTerm.isEmpty) {
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

    // 4) Φιλτράρισμα τοπικά
    final uid = _currentUser?.uid;
    final filtered = _allRecipes.where((doc) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final access = (data['access'] ?? '').toString();
      final createdBy = (data['createdBy'] ?? '').toString();
      return name.contains(_searchTerm) &&
          (access == 'public' || createdBy == uid);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No recipes found for "$_searchTerm"',
          style: TextStyle(color: Colors.grey, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 5) Εμφάνιση λίστας
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final doc = filtered[i];
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
}
