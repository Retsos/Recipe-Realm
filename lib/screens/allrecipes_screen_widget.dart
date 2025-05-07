  import 'dart:async';
import 'dart:io';
  import 'package:flutter/material.dart';
  import 'package:connectivity_plus/connectivity_plus.dart';
  import 'package:provider/provider.dart';
  import 'package:reciperealm/widgets/recipe_card.dart';
  import '../database/FirebaseService.dart';
  import 'package:reciperealm/widgets/guest_provider_widget.dart';
  import '../database/app_repo.dart';
  import '../main.dart';

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
    List<Map<String, dynamic>>? _recipes;
    bool _isConnected = true;
    bool _showOnlyMyRecipes = false;
    late final FirebaseService _firebaseService;
    bool _didInit = false;
    late final StreamSubscription _connSub;
    String? _selectedServingsRange;

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
        _connSub = Connectivity()
            .onConnectivityChanged
            .listen((result) async {
          final connected = result != ConnectivityResult.none;
          if (!mounted) return;
          if (connected != _isConnected) {
            setState(() => _isConnected = connected);
            await _checkConnectionAndLoadRecipes(showSnackbar: true);
          }
        }) ;

      }
    }

    @override
    void dispose() {
      _connSub.cancel();
      super.dispose();
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
      if (!mounted) return;
      setState(() => _isConnected = realNet);
      await _loadRecipes(realNet);
    }

    Future<void> _loadRecipes(bool realNet) async {
      setState(() => _isLoading = true);

      try {
        if (!realNet) {
          debugPrint('[DEBUG] Loading local recipes');
          _recipes = await _firebaseService.getLocalDefaultRecipes();
        } else {
          debugPrint('[DEBUG] Loading with filters: category=${_selectedCategory ?? 'all'}, servings=${_selectedServingsRange?.toString() ?? 'all'}, myRecipes=${_showOnlyMyRecipes}');

          // Case 1: Only my recipes filter
          if (_showOnlyMyRecipes && _firebaseService.currentUserId != null) {
            _recipes = await _firebaseService.getRecipesByUser(_firebaseService.currentUserId!);
          }
          // Case 2: Category filter
          else if (_selectedCategory != null && _selectedServingsRange == null) {
            _recipes = await _firebaseService.getRecipesByCategory(_selectedCategory!);
          }
          // Case 3: Servings filter
          else if (_selectedServingsRange != null && _selectedCategory == null) {
            _recipes = await _firebaseService.getRecipesByServingsRange(_selectedServingsRange!);
          }
          // Case 4: Category AND Servings filter
          else if (_selectedCategory != null && _selectedServingsRange != null) {
            debugPrint('[DEBUG] Filtering by both category (${_selectedCategory}) and servings (${_selectedServingsRange})');

            // First get by category (usually more restrictive)
            List<Map<String, dynamic>> categoryResults = await _firebaseService.getRecipesByCategory(_selectedCategory!);

            debugPrint('[DEBUG] Found ${categoryResults.length} recipes in category before servings filter');

            // Then filter by exact servings match in memory
            _recipes = categoryResults.where((recipe) {
              final servingsStr = recipe['servings'].toString().trim();
              debugPrint('[DEBUG] Recipe "${recipe['name']}" has servings: "$servingsStr"');

              // Handle special case for "4+"
              if (_selectedServingsRange == "4+") {
                // Check if the servings starts with 4, 5, 6, etc.
                if (servingsStr.startsWith("4") || servingsStr.startsWith("5") ||
                    servingsStr.startsWith("6") || servingsStr.startsWith("7") ||
                    servingsStr.startsWith("8") || servingsStr.startsWith("9")) {
                  return true;
                }
                // Also match if the first number in a range is >= 4
                if (servingsStr.contains("-")) {
                  final firstPart = servingsStr.split("-")[0].trim();
                  final firstNum = int.tryParse(firstPart) ?? 0;
                  return firstNum >= 4;
                }
                return false;
              }

              // For normal ranges, do an exact string match
              return servingsStr == _selectedServingsRange;
            }).toList();

            debugPrint('[DEBUG] Found ${_recipes!.length} recipes after servings filter');
          }          // Case 5: No specific filters
          else {
            _recipes = await _firebaseService.getAllRecipes();
          }

          debugPrint('[DEBUG] Final recipes loaded: ${_recipes!.length}');
        }
      } catch (e) {
        debugPrint('Error loading recipes: $e');
        _recipes = [];
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }    List<Map<String, dynamic>> _getFilteredRecipes() {
      if (_recipes == null) return [];

      return _recipes!.where((recipe) {
        // Prep time (μόνο τοπικά)
        if (_selectedPrepTime != null && !_matchesPrepTimeFilter(recipe['prepTime'])) {
          return false;
        }

        // Guest check (μόνο τοπικά)
        final metadata = recipe['metadata'] as Map<String, dynamic>;
        final createdBy = metadata['createdBy']?.toString().trim();
        final isGuest = Provider.of<GuestProvider>(context, listen: false).isGuest;
        if (isGuest && createdBy != "") {
          return false;
        }

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

      // Create temporary filter variables to not affect state until applied
      String? tempSelectedCategory = _selectedCategory;
      String? tempSelectedPrepTime = _selectedPrepTime;
      bool tempShowOnlyMyRecipes = _showOnlyMyRecipes;
      String? tempSelectedServingsRange = _selectedServingsRange;

      final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
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
                                color:  isDarkMode? Colors.grey[900] : Colors.grey,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Filter Recipes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,color: isDarkMode? Colors.white : Colors.black87)),
                          const SizedBox(height: 20),
                          Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                label: const Text('All'),
                                selected: tempSelectedCategory == null,
                                onSelected: (sel) => setModalState(() => tempSelectedCategory = sel ? null : tempSelectedCategory),
                                backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                                selectedColor: isDarkMode ? Colors.green[800] : Colors.green[100],
                              ),
                              ...['BreakFast','Lunch','Dinner'].map((cat) => FilterChip(
                                label: Text(cat),
                                selected: tempSelectedCategory == cat,
                                onSelected: (sel) => setModalState(() => tempSelectedCategory = sel ? cat : null),
                                backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                                selectedColor: isDarkMode ? Colors.green[800] : Colors.green[100],
                              )),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text('Servings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                label: const Text('All'),
                                selected: tempSelectedServingsRange == null,
                                backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                                selectedColor: isDarkMode ? Colors.green[800] : Colors.green[100],
                                onSelected: (_) => setModalState(() => tempSelectedServingsRange = null),
                              ),
                              // Change these to use string values instead of numeric ranges
                              FilterChip(
                                label: const Text('1-2'),
                                selected: tempSelectedServingsRange == "1-2",
                                backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                                selectedColor: isDarkMode ? Colors.green[800] : Colors.green[100],
                                onSelected: (_) => setModalState(() => tempSelectedServingsRange = "1-2"),
                              ),
                              FilterChip(
                                label: const Text('2-4'),
                                selected: tempSelectedServingsRange == "2-4",
                                backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                                selectedColor: isDarkMode ? Colors.green[800] : Colors.green[100],
                                onSelected: (_) => setModalState(() => tempSelectedServingsRange = "2-4"),
                              ),
                              FilterChip(
                                label: const Text('4+'),
                                selected: tempSelectedServingsRange == "4+",
                                backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                                selectedColor: isDarkMode ? Colors.green[800] : Colors.green[100],
                                onSelected: (_) => setModalState(() => tempSelectedServingsRange = "4+"),
                              ),
                            ],
                          ),
                          const Text('Preparation Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _prepTimeOptions.map((time) {
                              return FilterChip(
                                label: Text(time),
                                selected: (time=='All' ? tempSelectedPrepTime==null : tempSelectedPrepTime==time),
                                onSelected: (sel) => setModalState(() => tempSelectedPrepTime = sel ? (time=='All'?null:time) : tempSelectedPrepTime),
                                backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                                selectedColor: isDarkMode ? Colors.green[800] : Colors.green[100],
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          // Creator filter
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Only show recipes created by me',
                                  style: TextStyle(
                                    // αν είσαι offline, γκρι‐απενεργοποιημένο
                                    color: !_isConnected
                                        ? Colors.grey[400]
                                    // αλλιώς λευκό σε dark mode, ή σκούρο σχεδόν μαύρο σε light mode
                                        : (isDarkMode ? Colors.white : Colors.black87),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Switch(
                                value: tempShowOnlyMyRecipes,
                                onChanged: _isConnected
                                    ? (value) => setModalState(() => tempShowOnlyMyRecipes = value)
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
                                    // Clear all filter values in the dialog
                                    setModalState(() {
                                      tempSelectedCategory = null;
                                      tempSelectedPrepTime = null;
                                      tempShowOnlyMyRecipes = false;
                                      tempSelectedServingsRange = null;
                                    });
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
                                    // Apply all temporary filter values to the actual state
                                    Navigator.pop(ctx);
                                    if (!mounted) return;

                                    setState(() {
                                      _selectedCategory = tempSelectedCategory;
                                      _selectedPrepTime = tempSelectedPrepTime;
                                      _showOnlyMyRecipes = tempShowOnlyMyRecipes;
                                      _selectedServingsRange = tempSelectedServingsRange;
                                    });

                                    // Reload recipes with the new filters
                                    _loadRecipes(_isConnected);
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
// Active filters section with proper state management
    Widget _buildActiveFiltersSection() {
      final bool hasActiveFilters = _selectedPrepTime != null || _showOnlyMyRecipes || _selectedServingsRange != null;

      if (!hasActiveFilters) return Container();

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Active filters:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_selectedPrepTime != null)
              Chip(
                label: Text('Time: $_selectedPrepTime'),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() => _selectedPrepTime = null);
                  _loadRecipes(_isConnected);
                },
              ),
            if (_showOnlyMyRecipes)
              Chip(
                label: const Text('My Recipes'),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() => _showOnlyMyRecipes = false);
                  _loadRecipes(_isConnected);
                },
              ),
            if (_selectedServingsRange != null)
              Chip(
                label: Text('Servings: $_selectedServingsRange'),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() => _selectedServingsRange = null);
                  _loadRecipes(_isConnected);
                },
              ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedPrepTime = null;
                  _showOnlyMyRecipes = false;
                  _selectedServingsRange = null;
                  _selectedCategory = null;
                });
                _loadRecipes(_isConnected);
              },
              child: const Text('Clear All', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
    @override
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
            // Active filters section - now using the dedicated method
            _buildActiveFiltersSection(),
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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: MediaQuery.of(context).orientation == Orientation.portrait ? 0.7 : 1.2,
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
                        // Added indicator for own recipes
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
    // Updated category button method to properly trigger recipe loading
    Widget _buildCategoryButton(String text, bool isSelected) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: isSelected ? Colors.white : Colors.green[500],
          backgroundColor: isSelected ? Colors.green[500] : Colors.transparent,
          side: BorderSide(color: Colors.green[500]!),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () async {
          setState(() {
            _selectedCategory = text == 'All' ? null : text;
          });
          // Always reload recipes when category changes
          await _loadRecipes(_isConnected);
        },
        child: Text(text),
      );
    }
  }