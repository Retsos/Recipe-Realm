import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:reciperealm/widgets/recipe_card.dart';
import 'package:reciperealm/screens/login_register_widget.dart';
import '../widgets/auth_service.dart';
import '../main.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({Key? key}) : super(key: key);

  @override
  _SearchResultsScreenState createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildRecipeQuery() {
    final uid = _currentUser?.uid;
    final col = FirebaseFirestore.instance.collection('Recipe');
    if (uid == null) {
      return col.where('access', isEqualTo: 'public')
          .where('createdBy', isEqualTo: '');
    } else {
      return col.where(
        Filter.or(
          Filter('createdBy', isEqualTo: uid),
          Filter('access', isEqualTo: 'public'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search recipes by name...',
            hintStyle: TextStyle(color: isDarkMode ? Colors.grey[500] : Colors.grey[600]),
            border: InputBorder.none,
            suffixIcon: _searchTerm.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, color: isDarkMode ? Colors.white : Colors.black54),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchTerm = '';
                });
              },
            )
                : null,
          ),
          onChanged: (value) => setState(() => _searchTerm = value),
        ),
      ),
      body: _buildSearchResults(isDarkMode),
    );
  }

  Widget _buildSearchResults(bool isDarkMode) {
    if (_searchTerm.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              'Start typing to search recipe names',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    final query = _buildRecipeQuery();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((doc) {
          final name = (doc.data()['name'] ?? '').toString().toLowerCase();
          return name.contains(_searchTerm.toLowerCase());
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_food, size: 60, color: Colors.grey),
                const SizedBox(height: 20),
                Text(
                  'No recipes with name containing "$_searchTerm"',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final recipeId = doc.id;
            final data = doc.data();

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _currentUser != null
                  ? FirebaseFirestore.instance.collection('User').doc(_currentUser!.uid).snapshots()
                  : null,
              builder: (context, userSnap) {
                final favs = userSnap.data?.data()?['favorites'] as List<dynamic>? ?? [];
                final isFavorite = favs.contains(recipeId);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: RecipeCard(
                    documentId: recipeId,
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
          },
        );
      },
    );
  }  Future<void> _handleFavoriteToggle(BuildContext context, String recipeId, bool newVal) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to manage favorites.')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
      );
      return;
    }

    try {
      await AuthService.updateUserFavorite(recipeId, newVal);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update favorite: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}