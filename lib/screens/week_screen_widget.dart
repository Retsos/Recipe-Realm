import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../main.dart';
import '../widgets/auth_service.dart';
import 'login_register_widget.dart';

/// Model for a Recipe.
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

/// Returns the current month's name (e.g., "April").
String _getCurrentMonthName() {
  return DateFormat('MMMM', 'en_US').format(DateTime.now());
}

/// Generates a list of 7 dates starting today.
List<DateTime> getWeekDates() {
  final DateTime today = DateTime.now();
  return List.generate(7, (index) => today.add(Duration(days: index)));
}

/// Custom overlay message to show when a day is completed
class CompletionOverlay extends StatefulWidget {
  final String message;
  final String dayName;
  final VoidCallback onDismiss;

  const CompletionOverlay({
    Key? key,
    required this.message,
    required this.dayName,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<CompletionOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _slideAnimation = Tween(begin: -100.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.0, 0.5)),
    );

    Future.delayed(Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });

  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    // Colors adjusted for dark mode
    final bgGradientStart = isDarkMode ? Colors.green.shade700 : Colors.green.shade600;
    final bgGradientEnd = isDarkMode ? Colors.green.shade500 : Colors.green.shade400;
    final innerBg = isDarkMode ? Colors.grey[850]! : Colors.white.withAlpha(38);
    final iconBg = isDarkMode ? Colors.grey[900]! : Colors.white.withAlpha(51);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: _slideAnimation.value,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              margin: EdgeInsets.all(12),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [bgGradientStart, bgGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (isDarkMode ? Colors.black : Colors.green.shade200).withAlpha(128),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Day Complete!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${widget.dayName} meal plan is all set',
                              style: TextStyle(
                                color: Colors.white.withAlpha(230),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () {
                          _controller.reverse().then((_) {
                            widget.onDismiss();
                          });
                        },
                        padding: EdgeInsets.all(4),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: innerBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.amber.shade200,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  final Map<String, Map<String, String>> _dailyPlans = <String, Map<String, String>>{};
  List<Recipe> _recipeOptions = [];
  bool _showCompletionMessage = false;
  String _completionMessage = '';
  String _completedDayName = '';
  late StreamSubscription<dynamic> _connectivitySub;
  int _selectedDayIndex = 0;
  late Future<bool> _internetFuture;

  bool _hasInternet = true;

  final List<String> _completionMessages = [
    "Great job planning your meals! Preparing ahead makes healthy eating easier.",
    "Meal planning is a form of self-care. You're doing great!",
    "Well done! Having a plan helps reduce food waste and save money.",
    "Excellent planning! You're on your way to more nutritious and enjoyable meals.",
    "Perfect! With all meals planned, you can shop more efficiently.",
    "Amazing work! When you plan your meals, you're less likely to make impulsive food choices.",
    "Fantastic job completing your day's meal plan. Your future self will thank you!",
    "Meal planning success! This will help you maintain a balanced diet all week.",
    "You're doing great! Consistent meal planning leads to healthier eating habits.",
    "Brilliant planning! Now you can look forward to delicious meals all day."
  ];

  @override
  void initState() {
    super.initState();
    _subscribeConnectivity();
    _loadRecipes();
    _internetFuture = AuthService.hasRealInternet();
    _loadPlans();
  }

  void _subscribeConnectivity() {
    // Initial check
    Connectivity()
        .checkConnectivity()
        .then((result) =>
        setState(() => _hasInternet = result != ConnectivityResult.none));

    // Listen for changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
      setState(() => _hasInternet = isOnline);

      if (isOnline) {
        _loadRecipes();
        _loadPlans();
      }
    });
  }

  Future<List<Recipe>> _fetchRecipes() async {
    final snapshot = await FirebaseFirestore.instance.collection('Recipe').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Recipe(
        name: data['name'] as String? ?? 'No Name',
        image: data['image'] as String? ?? '',
        category: data['category'] as String? ?? 'Uncategorized',
      );
    }).toList();
  }

  Future<void> _loadRecipes() async {
    final recipes = await _fetchRecipes();
    if (!mounted) return; // ✅ προστασία
    setState(() {
      _recipeOptions = recipes;
    });
  }

  Future<void> _loadPlans() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docRef = FirebaseFirestore.instance.collection('User').doc(uid);
    final snapshot = await docRef.get();
    final data = snapshot.data() ?? {};
    final plans = (data['weeklyPlans'] as Map<String, dynamic>?) ?? {};
    plans.forEach((dateKey, value) {
      final planMap = value as Map<String, dynamic>;
      setState(() {
        _dailyPlans[dateKey] = {
          'BreakFast': planMap['BreakFast'] as String? ?? '',
          'lunch': planMap['lunch'] as String? ?? '',
          'dinner': planMap['dinner'] as String? ?? '',
        };
      });
    });
  }

  /// WHENEVER a day is fully planned, fire this once per tap
  void _onDayPlanCompleted(DateTime date) {
    final msg = _completionMessages[Random().nextInt(_completionMessages.length)];
    final dayName = DateFormat('EEEE').format(date);
    setState(() {
      _completionMessage   = msg;
      _completedDayName    = dayName;
      _showCompletionMessage = true;
    });
  }

  Future<void> _savePlan(DateTime date, Map<String, String> plan) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final docRef = FirebaseFirestore.instance.collection('User').doc(uid);

    // Ενημερώνουμε το ημερήσιο πλάνο
    await docRef.update({
      'weeklyPlans.$dateKey': plan,
      'weeklyPlansLastUpdated': Timestamp.now(),
    });

    setState(() {
      _dailyPlans[dateKey] = plan;
    });

    // Αν έχουν συμπληρωθεί και τα 3 γεύματα:
    if (plan.values.every((v) => v.isNotEmpty)) {
      _onDayPlanCompleted(date);

      // Σταθερές ώρες ειδοποιήσεων (UTC)
      final mealTimes = [
        {'mealType': 'BreakFast', 'hour': 6, 'minute': 0},   // 09:00 Athens
        {'mealType': 'lunch',     'hour': 11, 'minute': 0},  // 14:00 Athens
        {'mealType': 'dinner',    'hour': 16, 'minute': 0},  // 19:00 Athens
      ];

      ///TESTERS TO CHECK FOR NOTIFICATIONS IN THE NEXT MINUTE
      // Τώρα + 1 λεπτό
      // final nowUtc = DateTime.now().toUtc().add(Duration(minutes: 1));
      //
      // final hour = nowUtc.hour;
      // final minute = nowUtc.minute;
      //
      // final mealTimes = [
      //   {'mealType': 'BreakFast', 'hour': hour, 'minute': minute},
      //   {'mealType': 'lunch', 'hour': hour, 'minute': minute},
      //   {'mealType': 'dinner', 'hour': hour, 'minute': minute},
      // ];

      // final mealContents = {
      //   'BreakFast': plan['BreakFast'],
      //   'lunch': plan['lunch'],
      //   'dinner': plan['dinner'],
      // };

      await docRef.update({
        'mealNotificationTimes': mealTimes,
        // 'weeklyPlans.$dateKey': mealContents,
      });
    }

    // Snackbar επιβεβαίωσης
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Meal plan saved successfully'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  List<Recipe> _getRecipesByCategory(String category) {
    return _recipeOptions.where((recipe) => recipe.category == category).toList();
  }

  Recipe? getSelectedRecipe(String meal, List<Recipe> options, Map<String, String> plan) {
    return options.firstWhere(
          (recipe) => recipe.name == plan[meal],
      orElse: () => Recipe(name: '', image: '', category: ''),
    );
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }


  Widget _buildNoInternetWidget() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No Internet Connection',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'This feature requires an internet connection to sync your meal plans with the cloud.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              var connectivityResult = await (Connectivity().checkConnectivity());
              setState(() {
                _hasInternet = connectivityResult != ConnectivityResult.none;
              });
              if (_hasInternet) {
                _loadRecipes();
                _loadPlans();
              }
            },
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySummary(Map<String, String> plan) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final meals = plan.entries.where((e) => e.value.isNotEmpty).map((e) => e.key.capitalize()).toList();

    if (meals.isEmpty) {
      return Text(
        'No meals planned',
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: isDarkMode ? Colors.grey[400] : Colors.grey.shade600,
        ),
      );
    }

    return Row(
      children: [
        Icon(Icons.restaurant, size: 14, color: Colors.green.shade600),
        SizedBox(width: 4),
        Text(
          meals.join(' • '),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.grey[300] : Colors.green.shade700,
          ),
        ),
      ],
    );
  }

  ExpansionPanelRadio _buildDayPanel(DateTime date, int index) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    if (!_dailyPlans.containsKey(dateKey)) {
      _dailyPlans[dateKey] = {'BreakFast': '', 'lunch': '', 'dinner': ''};
    }
    final plan = _dailyPlans[dateKey]!;

    final optionsMap = {
      'BreakFast': _getRecipesByCategory('BreakFast'),
      'lunch': _getRecipesByCategory('Lunch'),
      'dinner': _getRecipesByCategory('Dinner'),
    };

    final now = DateTime.now();
    final bool isToday =
        now.year  == date.year &&
            now.month == date.month &&
            now.day   == date.day;

    final bool isComplete = plan.values.every((v) => v.isNotEmpty);
    final dayName = DateFormat('EEEE', 'en_US').format(date);

    Color headerBg;
    if (isToday) headerBg = isDarkMode ? Colors.black54: Colors.green.shade50;
    else if (isComplete) headerBg = isDarkMode ? Colors.black26 : Colors.green.shade50.withAlpha(128);
    else headerBg = isDarkMode ? Colors.grey[900]! : Colors.white;

    return ExpansionPanelRadio(
      value: dateKey,
      backgroundColor: headerBg,
      canTapOnHeader: true,
      headerBuilder: (context, isExpanded) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isExpanded ? Border.all(color: Colors.green.shade300, width: 1) : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Stack(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isToday  ? Colors.green.shade600
                        : isComplete  ? Colors.green.shade400
                        : (isDarkMode ? Colors.grey[700]! : Colors.blueGrey.shade50),
                    shape: BoxShape.circle,
                    boxShadow: (isToday || isComplete || isExpanded)
                        ? [BoxShadow(
                      color: (isDarkMode ? Colors.black : Colors.green.shade200).withAlpha(128),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: (isToday || isComplete)
                              ? Colors.white
                              : isDarkMode
                              ? Colors.grey[300]
                              : (isExpanded ? Colors.green.shade700 : Colors.blueGrey.shade700),
                        ),
                      ),
                      Text(
                        DateFormat('MMM', 'en_US').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: (isToday || isComplete)
                              ? Colors.white
                              : isDarkMode
                              ? Colors.grey[400]
                              : (isExpanded ? Colors.green.shade700 : Colors.blueGrey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isComplete)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[900] : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green.shade400, width: 1.5),
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.green.shade600,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: (isToday || isComplete || isExpanded) ? FontWeight.bold : FontWeight.w600,
                    color: isToday
                        ? Colors.green.shade800
                        : isComplete
                        ? Colors.green.shade700
                        : isDarkMode
                        ? Colors.grey[200]
                        : (isExpanded ? Colors.green.shade700 : Colors.blueGrey.shade800),
                  ),
                ),
                if (isToday)
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                if (isComplete && !isToday)
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'COMPLETE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: _buildDaySummary(plan),
            ),
          ),
        );
      },
      body: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850]! : Colors.grey.shade50,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          border: Border.all(
            color: Colors.green.shade200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var meal in ['BreakFast', 'lunch', 'dinner'])
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: RecipeDropdownItem(
                  label: meal.capitalize(),
                  icon: meal == 'BreakFast'
                      ? Icons.free_breakfast
                      : meal == 'lunch'
                      ? Icons.lunch_dining
                      : Icons.dinner_dining,
                  iconColor: meal == 'BreakFast'
                      ? Colors.orange.shade400
                      : meal == 'lunch'
                      ? Colors.blue.shade400
                      : Colors.deepPurple.shade400,
                  options: optionsMap[meal]!,
                  selectedOption: getSelectedRecipe(meal, optionsMap[meal]!, plan),
                  onSelected: (selected) {
                    plan[meal] = selected.name;
                    _savePlan(date, plan);
                  },
                ),
              ),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  plan.updateAll((key, value) => '');
                  _savePlan(date, plan);
                },
                icon: Icon(Icons.refresh, size: 18),
                label: Text('Reset Day'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? Colors.red.shade900 : Colors.red.shade50,
                  foregroundColor: isDarkMode ? Colors.white : Colors.red.shade700,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isDarkMode ? Colors.red.shade700 : Colors.red.shade200),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final weekDates = getWeekDates();
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    return FutureBuilder<bool>(
      future: _internetFuture,
      builder: (ctx, snap) {
        // 1) Εν αναμονή
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // 2) Χωρίς ίντερνετ ή λάθος
        if (snap.hasError || snap.data == false) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Weekly Meal Plan'),
              backgroundColor: Colors.green,
            ),
            body: _buildNoInternetWidget(),
          );
        }
        // 3) Έχεις ίντερνετ → κανονικό UI
        // Εδώ “κόλλησε” όλο το προηγούμενό σου Scaffold
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Weekly Meal Plan"),
              foregroundColor: isDarkMode? Colors.black : Colors.white,
              backgroundColor: Colors.green,
              elevation: 0,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 60, color: Colors.grey[500]),
                  const SizedBox(height: 16),
                  Text(
                    "Please sign in to access your meal plan.",
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
                      );
                    },
                    icon: Icon(Icons.login),
                    label: Text("Go to Login"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  )
                ],
              ),
            ),
          );
        }

        // helper to build just the header for day i:
        Widget _buildDayHeader(DateTime date, int index) {
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final plan = _dailyPlans[dateKey] ?? {'BreakFast':'','lunch':'','dinner':''};
          final dayName = DateFormat('EEEE','en_US').format(date);
          final isToday = DateTime.now().difference(date).inDays == 0;
          final isComplete = plan.values.every((v) => v.isNotEmpty);

          return ListTile(
            selected: index == _selectedDayIndex,
            leading: CircleAvatar(
              backgroundColor: isToday
                  ? Colors.green
                  : isComplete
                  ? Colors.green.shade300
                  : (isDarkMode ? Colors.grey[700] : Colors.grey[300]),
              child: Text(
                date.day.toString(),
                style: TextStyle(
                  color: isToday || isComplete ? Colors.white : Colors.black87,
                ),
              ),
            ),
            title: Text(
              dayName,
              style: TextStyle(
                fontWeight: index == _selectedDayIndex
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: _buildDaySummary(plan),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _selectedDayIndex = index),
          );
        }

        return Scaffold(
          backgroundColor: isDarkMode ? Colors.grey[900]! : Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              'Weekly Meal Plan',
              style: TextStyle(
                color: isDarkMode ? Colors.green[700] : Colors.green.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: isDarkMode ? Colors.grey[850]! : Colors.white,
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: isDarkMode ? Colors.grey[200] : Colors.green.shade700),
                onPressed: () {
                  setState(() {
                    _loadRecipes();
                    _loadPlans();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Refreshed plans'),
                      duration: Duration(seconds: 1),
                      backgroundColor: Colors.green.shade600,
                    ),
                  );
                },
                tooltip: 'Refresh plans',
              ),
            ],
          ),
          body:  Stack(
            children: [
              isLandscape
                  ? Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: ListView.builder(
                      itemCount: weekDates.length,
                      itemBuilder: (ctx, i) => _buildDayHeader(weekDates[i], i),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 2,
                    child: _recipeOptions.isEmpty
                        ? Center(/* loader */)
                        : SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 8),
                      child: ExpansionPanelList.radio(
                        animationDuration: const Duration(milliseconds: 500),
                        expandedHeaderPadding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          _buildDayPanel(
                            weekDates[_selectedDayIndex],
                            _selectedDayIndex,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[850]! : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? Colors.black.withAlpha(25)
                              : Colors.grey.withAlpha(25),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getCurrentMonthName(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.grey[100] : Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Plan your meals for the week ahead',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _recipeOptions.isEmpty
                        ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDarkMode ? Colors.green.shade300 : Colors.green,
                        ),
                      ),
                    )
                        : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Column(
                        children: [
                          ExpansionPanelList.radio(
                            animationDuration: const Duration(milliseconds: 500),
                            expandedHeaderPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                            elevation: 0,
                            children: List.generate(
                              weekDates.length,
                                  (index) => _buildDayPanel(weekDates[index], index),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_showCompletionMessage)
                CompletionOverlay(
                  message: _completionMessage,
                  dayName: _completedDayName,
                  onDismiss: () => setState(() => _showCompletionMessage = false),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Widget for displaying a recipe dropdown.
class RecipeDropdownItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final List<Recipe> options;
  final Recipe? selectedOption;
  final ValueChanged<Recipe> onSelected;

  const RecipeDropdownItem({
    super.key,
    required this.label,
    this.icon = Icons.food_bank,
    this.iconColor = Colors.green,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
  });

  String truncateMiddle(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    int keep = (maxLength / 2).floor();
    return '${text.substring(0, keep)}...${text.substring(text.length - keep)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDarkMode ? Colors.grey[800]! : Colors.white;
    final borderColor = selectedOption != null
        ? iconColor.withAlpha(120)
        : (isDarkMode ? Colors.grey[700]! : Colors.grey.shade200);

    final Recipe? dropdownValue = (selectedOption == null || selectedOption!.name.isEmpty)
        ? null
        : selectedOption;

    if (options.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'No recipes available',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDarkMode ? 50 : 20),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.grey[200] : Colors.grey.shade800,
                ),
              ),
              if (dropdownValue != null)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: iconColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: iconColor.withAlpha(120)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: iconColor,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              truncateMiddle(dropdownValue.name, 20),
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey[100] : Colors.grey.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                onSelected(Recipe(name: '', image: '', category: ''));
                              },
                              child: Icon(Icons.clear, size: 14, color: isDarkMode ? Colors.grey[400] : Colors.grey.shade700),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Recipe>(
            value: dropdownValue,
            isExpanded: true,
            hint: Text(
              'Select a recipe',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            icon: Icon(Icons.arrow_drop_down, color: isDarkMode ? Colors.grey[400] : Colors.grey.shade700),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: isDarkMode ? Colors.grey[700]! : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey.shade300, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey.shade300, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: iconColor, width: 2),
              ),
            ),
            iconSize: 24,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[100] : Colors.black87,
            ),
            dropdownColor: isDarkMode ? Colors.grey[800]! : Colors.white,
            menuMaxHeight: 300,
            items: options.map((Recipe recipe) {
              return DropdownMenuItem<Recipe>(
                value: recipe,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: recipe.image.isNotEmpty
                              ? NetworkImage(recipe.image)
                              : AssetImage('assets/placeholder.png') as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isDarkMode ? 70 : 26),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Tooltip(
                        message: recipe.name,
                        child: Text(
                          truncateMiddle(recipe.name, 30),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: isDarkMode ? Colors.grey[100] : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (Recipe? newSelected) {
              if (newSelected != null) onSelected(newSelected);
            },
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
