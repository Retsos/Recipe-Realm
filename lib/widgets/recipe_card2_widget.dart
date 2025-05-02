import 'package:flutter/material.dart';

class FullWidthRecipeCard extends StatelessWidget {
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
  final bool isFavorite;
  final Function(bool) onFavoritePressed;
  final Function() onDeletePressed;

  const FullWidthRecipeCard({
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
    required this.isFavorite,
    required this.onFavoritePressed,
    required this.onDeletePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Capture the navigator before the transition
        final navigator = Navigator.of(context);
        navigator.push(
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(
              documentId: documentId,
              name: name,
              imageUrl: imageUrl,
              prepTime: prepTime,
              servings: servings,
              Introduction: Introduction,
              category: category,
              difficulty: difficulty,
              isFavorite: isFavorite,
              onFavoritePressed: onFavoritePressed,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Left image section
            Hero(
              tag: 'recipe-image-$documentId',
              child: SizedBox(
                width: 120,
                height: 110,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            (loadingProgress.expectedTotalBytes ?? 1)
                            : null,
                        strokeWidth: 2,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade100,
                      child: const Icon(
                        Icons.restaurant,
                        size: 40,
                        color: Colors.grey,
                      ),
                    );
                  },
                )
                    : Container(
                  color: Colors.grey.shade100,
                  child: const Icon(
                    Icons.restaurant,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            // Right content section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category pill
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Recipe name
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Difficulty and time row
                    Row(
                      children: [
                        _buildDifficultyDot(difficulty),
                        const SizedBox(width: 6),
                        Text(
                          difficulty,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          prepTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Action buttons
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: () {
                    onFavoritePressed(!isFavorite);
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: onDeletePressed,
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyDot(String difficulty) {
    Color dotColor;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        dotColor = Colors.green;
        break;
      case 'medium':
        dotColor = Colors.orange;
        break;
      case 'hard':
        dotColor = Colors.red;
        break;
      default:
        dotColor = Colors.blue;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

// Separate detail screen class to ensure proper context management
class RecipeDetailScreen extends StatelessWidget {
  final String documentId;
  final String name;
  final String imageUrl;
  final String prepTime;
  final String servings;
  final String Introduction;
  final String category;
  final String difficulty;
  final bool isFavorite;
  final Function(bool) onFavoritePressed;

  const RecipeDetailScreen({
    Key? key,
    required this.documentId,
    required this.name,
    required this.imageUrl,
    required this.prepTime,
    required this.servings,
    required this.Introduction,
    required this.category,
    required this.difficulty,
    required this.isFavorite,
    required this.onFavoritePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ensure we have a valid context for ScaffoldMessenger here
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'recipe-image-$documentId',
                child: imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Handle image loading errors safely
                    return Container(
                      color: Colors.grey.shade100,
                      child: const Icon(
                        Icons.restaurant,
                        size: 60,
                        color: Colors.grey,
                      ),
                    );
                  },
                )
                    : Container(
                  color: Colors.grey.shade100,
                  child: const Icon(
                    Icons.restaurant,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: Colors.white,
                  ),
                ),
                onPressed: () {
                  try {
                    onFavoritePressed(!isFavorite);
                    // Only show snackbar if the toggle action was successful
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          isFavorite ? 'Removed from favorites' : 'Added to favorites',
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.black87,
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    // Handle errors if they occur
                    debugPrint('Error toggling favorite: $e');
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category pill
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Recipe title
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Recipe quick info
                  Row(
                    children: [
                      _buildInfoItem(Icons.access_time_outlined, prepTime),
                      const SizedBox(width: 24),
                      _buildInfoItem(Icons.person_outline, servings),
                      const SizedBox(width: 24),
                      _buildInfoItem(_getDifficultyIcon(difficulty), difficulty),
                    ],
                  ),
                  const Divider(height: 40),
                  Text(
                    'About',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    Introduction,
                    style: TextStyle(
                      height: 1.5,
                      fontSize: 15,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  // Additional sections would go here
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDifficultyIcon(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Icons.sunny;
      case 'medium':
        return Icons.trending_flat;
      case 'hard':
        return Icons.whatshot;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}