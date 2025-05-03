import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/app_repo.dart';
import '../main.dart';
import '../screens/recipe_screen_widget.dart';
import 'package:reciperealm/widgets/auth_service.dart';

class RecipeCard extends StatefulWidget {
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

  const RecipeCard({
    Key? key,
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
  }) : super(key: key);

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> with SingleTickerProviderStateMixin {
  late Future<bool> _isFavoriteFuture;
  bool _isProcessingFavorite = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();

    // Add animations for more visual interest
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadFavoriteStatus() {
    _isFavoriteFuture = _checkIfFavorite();
  }

  Future<bool> _checkIfFavorite() async {
    final repository = Provider.of<AppRepository>(context, listen: false);
    final favs = await repository.getFavorites();
    return favs.any((f) => f.documentId == widget.documentId);
  }

  static DateTime? _lastSnackbarTime;

  Future<bool> _hasRealInternet({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final result = await InternetAddress.lookup('example.com').timeout(timeout);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
  }

  Future<void> _handleFavoriteToggle() async {
    final repo = Provider.of<AppRepository>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      final now = DateTime.now();
      if (_lastSnackbarTime == null ||
          now.difference(_lastSnackbarTime!).inMilliseconds >= 2500) {
        _lastSnackbarTime = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to save favorites'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isProcessingFavorite = true);

    try {
      final isFav = await _isFavoriteFuture;
      final newState = !isFav;

      await repo.toggleFavorite(context, widget.documentId, newState);

      final online = await _hasRealInternet();
      if (online) {
        await repo.syncFavorites();
      }

      final now2 = DateTime.now();
      if (_lastSnackbarTime == null ||
          now2.difference(_lastSnackbarTime!).inMilliseconds >= 2500) {
        _lastSnackbarTime = now2;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newState ? 'Added to favorites' : 'Removed from favorites',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _loadFavoriteStatus();
          _isProcessingFavorite = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operation failed. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isProcessingFavorite = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;

    // Get the current orientation
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // Adjust layout based on orientation
    final cardWidth = isLandscape ? 320.0 : 248.0;
    final cardHeight = isLandscape ? 200.0 : 248.0;
    final imageHeight = isLandscape ? 140.0 : 120.0;

    return FutureBuilder<bool>(
      future: _isFavoriteFuture,
      builder: (context, snapshot) {
        final isFavorite = snapshot.data ?? false;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(
                  documentId: widget.documentId,
                  name: widget.name,
                  imageUrl: widget.imageUrl,
                  prepTime: widget.prepTime,
                  servings: widget.servings,
                  Introduction: widget.Introduction,
                  category: widget.category,
                  difficulty: widget.difficulty,
                  ingredientsAmount: widget.ingredientsAmount,
                  ingredients: widget.ingredients,
                  instructions: widget.instructions,
                ),
              ),
            );
          },
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: cardWidth,
              height: cardHeight,
              margin: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withAlpha(60)
                        : Colors.black.withAlpha(20),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                elevation: 0, // Remove default elevation as we use custom shadow
                clipBehavior: Clip.antiAlias,
                child: isLandscape ? _buildLandscapeLayout(
                    isDarkMode,
                    colorScheme,
                    isFavorite,
                    imageHeight
                ) : _buildPortraitLayout(
                    isDarkMode,
                    colorScheme,
                    isFavorite,
                    imageHeight
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Portrait layout (vertical)
  Widget _buildPortraitLayout(
      bool isDarkMode, ColorScheme colorScheme, bool isFavorite, double imageHeight) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: _buildImage(),
            ),

            // Recipe Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Difficulty indicator
                    Row(
                      children: [
                        _buildDifficultyIndicator(isDarkMode),
                        const Spacer(),
                      ],
                    ),

                    const Spacer(),

                    // Time and servings info
                    Row(
                      children: [
                        _buildInfoItem(
                          icon: Icons.timer,
                          text: widget.prepTime,
                          isDarkMode: isDarkMode,
                        ),
                        _buildInfoItem(
                          icon: Icons.people,
                          text: widget.servings,
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Favorite button
        Positioned(
          top: 8,
          right: 8,
          child: _buildFavoriteButton(isFavorite, colorScheme, isDarkMode),
        ),

        // Category tag
        Positioned(
          top: imageHeight - 16,
          left: 12,
          child: _buildCategoryTag(isDarkMode),
        ),
      ],
    );
  }

  // Landscape layout (horizontal)
  Widget _buildLandscapeLayout(
      bool isDarkMode, ColorScheme colorScheme, bool isFavorite, double imageHeight) {
    return Stack(
      children: [
        Row(
          children: [
            // Image on the left
            SizedBox(
              width: 140,
              height: double.infinity,
              child: _buildImage(),
            ),

            // Content on the right
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Difficulty indicator
                    _buildDifficultyIndicator(isDarkMode),

                    const Spacer(),

                    // Time and servings info
                    Row(
                      children: [
                        _buildInfoItem(
                          icon: Icons.timer,
                          text: widget.prepTime,
                          isDarkMode: isDarkMode,
                        ),
                        _buildInfoItem(
                          icon: Icons.people,
                          text: widget.servings,
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Favorite button
        Positioned(
          top: 8,
          right: 8,
          child: _buildFavoriteButton(isFavorite, colorScheme, isDarkMode),
        ),

        // Category tag
        Positioned(
          top: 8,
          left: 8,
          child: _buildCategoryTag(isDarkMode),
        ),
      ],
    );
  }

  Widget _buildImage() {
    if (widget.imageUrl.startsWith('assets/')) {
      return Image.asset(
        widget.imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (c, e, st) => _buildPlaceholderImage(),
      );
    }
    if (widget.imageUrl.isEmpty) return _buildPlaceholderImage();
    return Image.network(
      widget.imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (c, child, progress) =>
      progress == null ? child : Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[200],
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded /
                progress.expectedTotalBytes!
                : null,
          ),
        ),
      ),
      errorBuilder: (c, e, st) => _buildPlaceholderImage(),
    );
  }

  Widget _buildPlaceholderImage() => Container(
    width: double.infinity,
    height: double.infinity,
    color: Colors.grey[300],
    child: const Icon(Icons.image, size: 50, color: Colors.grey),
  );

  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    required bool isDarkMode
  }) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
            icon,
            size: 16,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[700]
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _buildFavoriteButton(bool isFavorite, ColorScheme cs, bool isDarkMode) => Material(
    color: Colors.transparent,
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: _handleFavoriteToggle,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900]!.withOpacity(0.7) : cs.surface.withOpacity(0.7),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8.0),
        child: _isProcessingFavorite
            ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
                Colors.green[500]!),
          ),
        )
            : Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: Colors.red[400],
          size: 20,
        ),
      ),
    ),
  );

  Widget _buildCategoryTag(bool isDarkMode) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.green[800]!.withOpacity(0.8)
            : Colors.green[50]!.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1)
          )
        ]
    ),
    child: Text(
      widget.category,
      style: TextStyle(
        color: isDarkMode ? Colors.green[100] : Colors.green[800],
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildDifficultyIndicator(bool isDarkMode) {
    Color getColor() {
      switch (widget.difficulty.toLowerCase()) {
        case 'easy':
          return Colors.green;
        case 'medium':
          return Colors.orange;
        case 'hard':
          return Colors.red;
        default:
          return Colors.blue;
      }
    }

    final difficultyColor = getColor();

    return Row(
      children: [
        Icon(
            Icons.star,
            size: 14,
            color: difficultyColor
        ),
        const SizedBox(width: 4),
        Text(
          widget.difficulty,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}