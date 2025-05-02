  import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
  import 'package:connectivity_plus/connectivity_plus.dart';
  import 'package:provider/provider.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:reciperealm/widgets/recipe_card.dart';
  import '../database/FirebaseService.dart';
  import 'package:reciperealm/widgets/guest_provider_widget.dart';

import '../database/app_repo.dart';

  class AllRecipesScreen extends StatefulWidget {
    final String? initialCategory;

    const AllRecipesScreen({Key? key, this.initialCategory}) : super(key: key);

    @override
    State<AllRecipesScreen> createState() => _AllRecipesScreenState();
  }

  class _AllRecipesScreenState extends State<AllRecipesScreen> {
    String? _selectedCategory;
    String? _selectedPrepTime;
    bool _isLoading = true;
    List<Map<String, dynamic>>? _recipes; // Changed to Map to handle both local and firestore recipes
    bool _isConnected = true;
    bool _showOnlyMyRecipes = false; // Added for filtering by creator
    String? _currentUserId;
    late final FirebaseService _firebaseService;
    bool _didInit = false;

    Future<bool> hasRealInternet({Duration timeout = const Duration(seconds: 5)}) async {
      try {
        final result = await InternetAddress.lookup('example.com').timeout(timeout);
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } on SocketException catch (_) {
        return false;
      } on TimeoutException catch (_) {
        return false;
      }
    }

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      if (!_didInit) {
        _didInit = true;
        final repo = Provider.of<AppRepository>(context, listen: false);
        _firebaseService = FirebaseService(repo);

        // μόλις έχεις service, τσέκαρε σύνδεση & φόρτωσε recipes
        _checkConnectionAndLoadRecipes();
        Connectivity().onConnectivityChanged.listen((result) {
          final connected = result != ConnectivityResult.none;
          if (connected != _isConnected) {
            setState(() => _isConnected = connected);
            _checkConnectionAndLoadRecipes(showSnackbar: true);
          }
        });
      }
    }


    final List<String> _prepTimeOptions = [
      'All', '0-15min', '15-30min', '30-60min', '60+min'
    ];

    @override
    void initState() {
      super.initState();
      _selectedCategory = widget.initialCategory;
    }

    bool _hasShownOfflineSnackbar = false;

    Future<void> _checkConnectionAndLoadRecipes({bool showSnackbar = false}) async {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasNet = connectivityResult != ConnectivityResult.none;
      final realNet = hasNet && await hasRealInternet();
      if (!realNet && showSnackbar && !_hasShownOfflineSnackbar) {
        _hasShownOfflineSnackbar = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline: showing only default recipes'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _isConnected = realNet);
      await _loadRecipes(realNet);
    }


    Future<void> _loadRecipes(bool fromFirestore) async {
      setState(() => _isLoading = true);
      try {
        if (fromFirestore) {
          try {
            _recipes = await _firebaseService.getAllRecipes();
          } catch (e) {
            debugPrint('Firestore load failed ($e), falling back to local defaults');
            _recipes = await _firebaseService.getLocalDefaultRecipes();
          }
        } else {
          _recipes = await _firebaseService.getLocalDefaultRecipes();
        }
      } catch (e) {
        debugPrint('Unexpected error loading recipes: $e');
        _recipes = [];
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    List<Map<String, dynamic>> _getFilteredRecipes() {
      if (_recipes == null) return [];


        return _recipes!.where((recipe) {
        // 1) Όχι άλλων χρηστών αν είσαι guest
          final metadata = recipe['metadata'] as Map<String, dynamic>;
          final createdBy = metadata['createdBy']?.toString().trim();

          final isGuest = Provider.of<GuestProvider>(context, listen: false).isGuest;
          if (isGuest && createdBy != "") {
            return false;
          }

          // Category filter
        if (_selectedCategory != null && recipe['category'] != _selectedCategory) return false;

        // Prep time filter
        if (_selectedPrepTime != null && !_matchesPrepTimeFilter(recipe['prepTime'])) return false;

        // My recipes filter
        if (_showOnlyMyRecipes && !(recipe['metadata'] as Map<String, dynamic>)['isOwnRecipe']) return false;

        return true;
      }).toList();
    }

    bool _matchesPrepTimeFilter(String prepTime) {
      if (_selectedPrepTime == null) return true;

      final numbers = RegExp(r'\d+').allMatches(prepTime);
      if (numbers.isEmpty) return false;

      // Handle potential null values with proper fallbacks
      final lastMatch = numbers.last.group(0);
      final lastNumber = int.tryParse(lastMatch ?? '') ?? 0;

      switch (_selectedPrepTime) {
        case '0-15min':  return lastNumber <= 15;
        case '15-30min': return lastNumber > 15 && lastNumber <= 30;
        case '30-60min': return lastNumber > 30 && lastNumber <= 60;
        case '60+min':   return lastNumber > 60;
        default:         return true;
      }
    }

    void _showFilterDialog() {
      if (!_isConnected) {
        debugPrint('Filter dialog blocked: offline');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filtering is disabled offline.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext ctx) {
          return StatefulBuilder(
            builder: (BuildContext ctx, StateSetter setModalState) {
              final double keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
              final double availableHeight = MediaQuery.of(ctx).size.height -
                  MediaQuery.of(ctx).padding.top -
                  kToolbarHeight -
                  keyboardHeight;

              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom),
                child: Container(
                  constraints: BoxConstraints(maxHeight: availableHeight * 0.85),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('Filter Recipes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          const Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                label: const Text('All'),
                                selected: _selectedCategory == null,
                                onSelected: (sel) => setModalState(() => _selectedCategory = sel ? null : _selectedCategory),
                                backgroundColor: Colors.grey[200],
                                selectedColor: Colors.green[100],
                              ),
                              ...['BreakFast','Lunch','Dinner'].map((cat) => FilterChip(
                                label: Text(cat),
                                selected: _selectedCategory == cat,
                                onSelected: (sel) => setModalState(() => _selectedCategory = sel ? cat : null),
                                backgroundColor: Colors.grey[200],
                                selectedColor: Colors.green[100],
                              )),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text('Preparation Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _prepTimeOptions.map((time) {
                              return FilterChip(
                                label: Text(time),
                                selected: (time=='All' ? _selectedPrepTime==null : _selectedPrepTime==time),
                                onSelected: (sel) => setModalState(() => _selectedPrepTime = sel ? (time=='All'?null:time) : _selectedPrepTime),
                                backgroundColor: Colors.grey[200],
                                selectedColor: Colors.green[100],
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          // Creator filter
                          Row(
                            children: [
                              Expanded(child: Text('Only show recipes created by me',
                                  style: TextStyle(color: _isConnected ? Colors.black : Colors.grey))),
                              Switch(
                                value: _showOnlyMyRecipes,
                                onChanged: _isConnected
                                    ? (value) => setModalState(() => _showOnlyMyRecipes = value)
                                    : null,
                                activeColor: Colors.green[700],
                              ),
                            ],
                          ),
                          if (!_isConnected)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: Text('Not available with local database', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setModalState(() {
                                      _selectedCategory = null;
                                      _selectedPrepTime = null;
                                      _showOnlyMyRecipes = false;
                                    });
                                    Navigator.pop(ctx);
                                    setState(() {});
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green[700],
                                    side: BorderSide(color: Colors.green[700]!),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text('Clear Filters'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    setState(() {});
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[700],
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text(
                                    'Apply Filters',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('All Recipes'),
          backgroundColor: Colors.green[500],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.green[500],
          foregroundColor: Colors.white,
          onPressed: _showFilterDialog,
          child: const Icon(Icons.filter_list),
          tooltip: 'Filter recipes',
        ),
        body: Column(
          children: [
            if (!_isConnected)
              Container(
                width: double.infinity,
                color: Colors.redAccent,
                padding: const EdgeInsets.all(8),
                child: const Center(
                  child: Text('Offline: showing default recipes only', style: TextStyle(color: Colors.white)),
                ),
              ),
            // Category buttons row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryButton('All', _selectedCategory == null),
                    const SizedBox(width: 8),
                    _buildCategoryButton('BreakFast', _selectedCategory == 'BreakFast'),
                    const SizedBox(width: 8),
                    _buildCategoryButton('Lunch', _selectedCategory == 'Lunch'),
                    const SizedBox(width: 8),
                    _buildCategoryButton('Dinner', _selectedCategory == 'Dinner'),
                  ],
                ),
              ),
            ),
            // Active filters section
            if (_selectedPrepTime != null || _showOnlyMyRecipes)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    const Text('Active filters:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    if (_selectedPrepTime != null)
                      Chip(
                        label: Text('Time: $_selectedPrepTime'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setState(() => _selectedPrepTime = null),
                      ),
                    if (_showOnlyMyRecipes)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Chip(
                          label: const Text('My Recipes'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _showOnlyMyRecipes = false),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(builder: (context) {
                final filtered = _getFilteredRecipes();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No recipes match your filters.'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final recipe = filtered[i];
                    final metadata = recipe['metadata'] as Map<String, dynamic>;

                    // Check if this is a user's own recipe
                    final isOwnRecipe = metadata['isOwnRecipe'] == true;

                    return Stack(
                      children: [
                        RecipeCard(
                          documentId: recipe['documentId'],
                          name: recipe['name'],
                          imageUrl: _isConnected
                              ? (recipe['imageUrl'] ?? recipe['assetPath'])
                              : recipe['assetPath'],
                          prepTime: recipe['prepTime'],
                          servings: recipe['servings'],
                          Introduction: recipe['Introduction'],
                          category: recipe['category'],
                          difficulty: recipe['difficulty'],
                          ingredientsAmount: recipe['ingredientsAmount'],
                          ingredients: List<String>.from(recipe['ingredients']),
                          instructions: List<String>.from(recipe['instructions']),
                        ),
                        // Add indicator for own recipes
                        if (isOwnRecipe)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(208),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'My Recipe',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              }),
            ),
          ],
        ),
      );
    }

    Widget _buildCategoryButton(String text, bool isSelected) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: isSelected ? Colors.white : Colors.green[500],
          backgroundColor: isSelected ? Colors.green[500] : Colors.transparent,
          side: BorderSide(color: Colors.green[500]!),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => setState(() => _selectedCategory = text=='All'?null:text),
        child: Text(text),
      );
    }
  }