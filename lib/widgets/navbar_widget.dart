import 'package:flutter/material.dart';

class NavbarWidget extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const NavbarWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.calendar_view_week), label: 'Week'),
        NavigationDestination(icon: Icon(Icons.food_bank), label: 'MyRecipe'),
        NavigationDestination(icon: Icon(Icons.favorite), label: 'Favorites'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
      ],
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
    );
  }
}
