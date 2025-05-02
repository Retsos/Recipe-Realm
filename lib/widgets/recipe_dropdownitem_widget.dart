import 'package:flutter/material.dart';

class Recipe {
  final String name;
  final String image;
  final String category;

  Recipe({
    required this.name,
    required this.image,
    required this.category,
  });
}

class RecipeDropdownItem extends StatelessWidget {
  final String label;
  final List<Recipe> options;
  final Recipe? selectedOption;
  final ValueChanged<Recipe?> onSelected;
  final VoidCallback onClear;

  const RecipeDropdownItem({
    super.key,
    required this.label,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
    required this.onClear,
  });

  // Truncate the text in the middle if it exceeds maxLength.
  String truncateMiddle(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    int keep = (maxLength / 2).floor();
    return '${text.substring(0, keep)}...${text.substring(text.length - keep)}';
  }

  @override
  Widget build(BuildContext context) {
    final Recipe? dropdownValue = (selectedOption == null || selectedOption!.name.isEmpty)
        ? null
        : selectedOption;

    // If there are no options, show a disabled message.
    if (options.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text('No recipes available', style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<Recipe>(
                value: dropdownValue,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'Select a recipe',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: options.map((Recipe recipe) {
                  return DropdownMenuItem<Recipe>(
                    value: recipe,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: recipe.image.isNotEmpty
                              ? NetworkImage(recipe.image)
                              : const AssetImage('assets/placeholder.png') as ImageProvider,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Tooltip(
                            message: recipe.name,
                            child: Text(
                              truncateMiddle(recipe.name, 30),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (Recipe? newSelected) {
                  onSelected(newSelected);
                },
              ),
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.clear, color: Colors.red),
              tooltip: 'Clear selection',
            ),
          ],
        ),
      ],
    );
  }
}
