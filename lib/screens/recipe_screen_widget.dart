import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../database/app_repo.dart';
import '../main.dart';
import '../database/entities.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String documentId;
  final String name;
  final String imageUrl;
  final String prepTime;
  final String servings;
  final String Introduction;
  final String category;
  final String difficulty;
  final String ingredientsAmount;
  final List<String> ingredients;
  final List<String> instructions;

  const RecipeDetailScreen({
    super.key,
    required this.documentId,
    required this.name,
    required this.imageUrl,
    required this.prepTime,
    required this.servings,
    required this.Introduction,
    required this.category,
    required this.difficulty,
    required this.ingredientsAmount,
    required this.ingredients,
    required this.instructions,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessingFavorite = false;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Set up connectivity listener
    Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
    });

    // Initial connectivity check
    Connectivity().checkConnectivity().then((result) {
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleFavoriteToggle() async {
    final repository = Provider.of<AppRepository>(context, listen: false);
    setState(() => _isProcessingFavorite = true);

    try {
      final currentState = await repository.localDb.favoriteRecipeDao
          .findFavorite(widget.documentId) != null;

      await repository.toggleFavorite(context,widget.documentId, !currentState);
    } finally {
      if (mounted) {
        setState(() => _isProcessingFavorite = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Offline banner
            if (!_isConnected)
              Container(
                width: double.infinity,
                color: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const Center(
                  child: Text(
                    'Offline: Favorites & new recipes disabled',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            // Main content
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Recipe image
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        _buildImage(),
                        // Back button
                        Positioned(
                          top: 16,
                          left: 16,
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withOpacity(0.5),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Recipe content
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.surface,
                            colorScheme.surfaceContainerHighest,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildTitleRow(context),
                          const SizedBox(height: 16),
                          _buildInfoBar(),
                          const SizedBox(height: 20),
                          _buildIntroduction(),
                          const SizedBox(height: 24),
                          _buildTabBar(),
                          _buildTabViews(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    // Check if the imageUrl is a local asset or a network image
    if (widget.imageUrl.startsWith('assets/')) {
      return Image.asset(
        widget.imageUrl,
        width: double.infinity,
        height: 250,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
      );
    } else if (widget.imageUrl.isNotEmpty) {
      return Image.network(
        widget.imageUrl,
        width: double.infinity,
        height: 250,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
      );
    } else {
      return _buildImagePlaceholder();
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 250,
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 100, color: Colors.grey),
    );
  }

  Widget _buildTitleRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: FutureBuilder<FavoriteRecipeEntity?>(
        future: Provider.of<AppRepository>(context, listen: false)
            .localDb.favoriteRecipeDao
            .findFavorite(widget.documentId),
        builder: (context, snapshot) {
          final isFavorite = snapshot.data != null;

          return Row(
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                icon: _isProcessingFavorite
                    ? const CircularProgressIndicator()
                    : Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                ),
                onPressed: _isConnected && !_isProcessingFavorite
                    ? _handleFavoriteToggle
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _InfoColumn(
            icon: Icons.timer,
            title: "Prep Time",
            value: widget.prepTime,
          ),
          _InfoColumn(
            icon: Icons.restaurant,
            title: "Servings",
            value: widget.servings,
          ),
          _InfoColumn(
            icon: Icons.speed,
            title: "Difficulty",
            value: widget.difficulty,
          ),
          _InfoColumn(
            customIcon: Image.asset(
              'assets/ingredient.png',
              width: 20,
              height: 20,
              color: Colors.white,
            ),
            title: "Ingredients",
            value: widget.ingredientsAmount,
          ),
        ],
      ),
    );
  }

  Widget _buildIntroduction() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Text(
        widget.Introduction,
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.start,
      ),
    );
  }

  Widget _buildTabBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDarkMode ? colorScheme.surface : Colors.green[100],
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: isDarkMode ? colorScheme.primary : Colors.green[800],
        unselectedLabelColor: colorScheme.onSurface.withAlpha(144),
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontSize: 16,
        ),
        unselectedLabelStyle: Theme.of(context).textTheme.labelMedium,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            width: 3.0,
            color: Colors.green,
          ),
          insets: const EdgeInsets.symmetric(horizontal: 24.0),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          Tab(
            text: "Ingredients",
            iconMargin: EdgeInsets.only(bottom: 4),
          ),
          Tab(
            text: "Instructions",
            iconMargin: EdgeInsets.only(bottom: 4),
          ),
        ],
        onTap: (index) {
          // Optional: Add haptic feedback
          HapticFeedback.selectionClick();
        },
      ),
    );
  }
  Widget _buildTabViews() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      height: 300,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildIngredientsTab(),
          _buildInstructionsTab(),
        ],
      ),
    );
  }

  Widget _buildIngredientsTab() {
    return ListView.builder(
      itemCount: widget.ingredients.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            "${index + 1}. ${widget.ingredients[index]}",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      },
    );
  }

  Widget _buildInstructionsTab() {
    return ListView.builder(
      itemCount: widget.instructions.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("• ", style: TextStyle(fontSize: 18)),
              Expanded(
                child: Text(
                  widget.instructions[index],
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String title;
  final String value;

  const _InfoColumn({
    this.icon,
    this.customIcon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        customIcon ?? Icon(icon, size: 20, color: Colors.white),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}