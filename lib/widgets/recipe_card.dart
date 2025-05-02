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

class _RecipeCardState extends State<RecipeCard> {
  late Future<bool> _isFavoriteFuture;
  bool _isProcessingFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
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

  Future<void> _handleFavoriteToggle() async {
    final repo = Provider.of<AppRepository>(context, listen: false);
    final User? user = FirebaseAuth.instance.currentUser;

    // First check if user is logged in

    if (user == null) {
      // User is not logged in, show a SnackBar

      final now = DateTime.now();

      // Αν έχει περάσει λιγότερο από 2.5 δευτερόλ  επτα, δεν δειχνω νέο Snackbar
      if (_lastSnackbarTime != null &&
          now.difference(_lastSnackbarTime!).inMilliseconds < 2500) {
        return;
      }

      _lastSnackbarTime = now;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to save favorites'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return; // Exit the method early
    }
    print(user);
    setState(() => _isProcessingFavorite = true);

    try {
      // Continue with existing favorite toggle logic
      // 1. Read current state
      final isFav = await _isFavoriteFuture;
      final newState = !isFav;

      // 2. Write locally (marked synced=false if adding)
      await repo.toggleFavorite(context,widget.documentId, newState);

      // 3. If online, push immediately; else show offline SnackBar
      if (await repo.isConnected()) {
        await repo.syncFavorites();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet — favorite will sync when back online'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 4. Provide UI feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newState
                ? 'Added to favorites'
                : 'Removed from favorites'),
          ),
        );
        // refresh local‐read future
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
    final colorScheme = Theme
        .of(context)
        .colorScheme;

    return FutureBuilder<bool>(
      future: _isFavoriteFuture,
      builder: (context, snapshot) {
        final isFavorite = snapshot.data ?? false;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    RecipeDetailScreen(
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
          child: Container(
            width: 250,
            height: 250,
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 3,
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: _buildImage(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          widget.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 8.0),
                        child: Row(
                          children: [
                            _buildInfoItem(
                              icon: Icons.timer,
                              text: widget.prepTime,
                            ),
                            _buildInfoItem(
                              icon: Icons.people,
                              text: widget.servings,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildFavoriteButton(isFavorite, colorScheme),
                  ),
                  Positioned(
                    bottom: 30,
                    right: 8,
                    child: _buildCategoryTag(isDarkMode),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage() {
    if (widget.imageUrl.startsWith('assets/')) {
      return Image.asset(
        widget.imageUrl,
        width: double.infinity,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (c, e, st) => _buildPlaceholderImage(),
      );
    }
    if (widget.imageUrl.isEmpty) return _buildPlaceholderImage();
    return Image.network(
      widget.imageUrl,
      width: double.infinity,
      height: 120,
      fit: BoxFit.cover,
      loadingBuilder: (c, child, progress) =>
      progress == null ? child : Container(
        width: double.infinity,
        height: 120,
        color: Colors.grey[200],
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
                Colors.green[300]!),
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

  Widget _buildPlaceholderImage() =>
      Container(
        width: double.infinity,
        height: 120,
        color: Colors.grey[300],
        child: const Icon(Icons.image, size: 50, color: Colors.grey),
      );

  Widget _buildInfoItem({required IconData icon, required String text}) =>
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  Widget _buildFavoriteButton(bool isFavorite, ColorScheme cs) =>
      GestureDetector(
        onTap: _handleFavoriteToggle,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6.0),
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
            color: Colors.red,
            size: 20,
          ),
        ),
      );

  Widget _buildCategoryTag(bool isDarkMode) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.green[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          widget.category,
          style: TextStyle(
            color: isDarkMode ? Colors.green[100] : Colors.green[800],
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}
