import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:reciperealm/screens/favourites_screen_widget.dart';
import 'package:reciperealm/screens/settings_screen_widget.dart';
import 'package:reciperealm/screens/welcome2_screen_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/app_repo.dart';
import 'database/entities.dart';
import 'firebase_options.dart';
import 'package:reciperealm/screens/home_screen_widget.dart';
import 'package:reciperealm/screens/week_screen_widget.dart';
import 'package:reciperealm/widgets/navbar_widget.dart';
import 'package:reciperealm/screens/contact_screen_widget.dart';
import 'package:reciperealm/screens/createrecipe_screen_widget.dart';
import 'package:reciperealm/widgets/guest_provider_widget.dart';
import 'package:provider/provider.dart';
import 'package:reciperealm/widgets/auth_service.dart';
import 'package:reciperealm/screens/welcome_screen_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:reciperealm/database/database_provider.dart';

// Δημιουργία νέου Provider για το theme
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  final AppRepository? _repository;  // Optional dependency for saves

  ThemeProvider({AppRepository? repository}) : _repository = repository;

  bool get isDarkMode => _isDarkMode;

  // Enhanced toggle method that also saves to the repository
  void toggleDarkMode(bool value) {
    _isDarkMode = value;

    // If we have a repository, save to database
    if (_repository != null) {
      _repository.updateSetting(
        UserSettingEntity.darkTheme(value),
      );
    }

    notifyListeners();
  }
  // Load settings from repository
  Future<void> loadSavedTheme() async {
    if (_repository != null) {
      final settings = await _repository.getSettings();
      if (_isDarkMode != settings.darkTheme) {
        _isDarkMode = settings.darkTheme;
        notifyListeners();
      }
    }
  }
}
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  Provider.debugCheckInvalidValueType = null;
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://anrtzhovvdbhrfhfcxia.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFucnR6aG92dmRiaHJmaGZjeGlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDM3OTc3NzMsImV4cCI6MjA1OTM3Mzc3M30.xmWwwJoxECRrLgHuD4HRll-iUP2CPJrZyweaFxSU5As',
  );

  final database = await DatabaseProvider.getInstance();
  final firestore = FirebaseFirestore.instance;
  final connectivity = Connectivity();

  final repository = AppRepository(
    localDb: database,
    firestore: firestore,
    connectivity: connectivity,
  );


  AuthService.configure(repository);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GuestProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        StreamProvider<firebase_auth.User?>(
          create: (_) => firebase_auth.FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),

        ChangeNotifierProvider<AppRepository>.value(value: repository),
      ],
      child: const MyApp(),
    ),
  );

}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    final repository = Provider.of<AppRepository>(context, listen: false);
    repository.startSyncListener();
    AuthService.startAuthLogging();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Recipe Realm',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: const AuthGate(),
    );
  }

  ThemeData _buildLightTheme() {
    final base = ThemeData.light(useMaterial3: true);
    final cs = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.light,
    );
    return base.copyWith(
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
      ),
      cardTheme: CardTheme(
        color: cs.surface,
        elevation: 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(cs.primary),
        trackColor: WidgetStateProperty.all(cs.primary.withAlpha(128)),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    final cs = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.dark,
    );

    return base.copyWith(
      colorScheme: cs,

      // Scaffold background stays the same
      scaffoldBackgroundColor: cs.surface,

      // AppBar now uses your primary color (with onPrimary text/icon color)
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black87,
        foregroundColor: cs.onPrimary,
        elevation: 1,
        centerTitle: false,
      ),

      // Bottom nav and cards (unchanged except for colors pulled from cs)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
      ),
      cardTheme: CardTheme(
        color: cs.surfaceContainerHighest,
        elevation: 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Switch thumb/track colors
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(cs.primary),
        trackColor: WidgetStateProperty.all(cs.primary.withAlpha(128)),
      ),

      // === NEW: Style all your input fields ===
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.onSurfaceVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.onSurfaceVariant.withAlpha(130)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _isGuestModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final guest = prefs.getBool('is_guest_logged_in') ?? false;
    return guest;
  }

  Future<bool> _checkNeedsOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final needs = prefs.getBool('needs_onboarding') ?? false;
    return needs;
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<firebase_auth.User?>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final repository = Provider.of<AppRepository>(context, listen: false);

    // Φόρτωσε το theme (1η φορά)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = await repository.getSettings();
      themeProvider.toggleDarkMode(settings.darkTheme);
    });

    return FutureBuilder<bool>(
      future: _isGuestModeEnabled(),
      builder: (context, snapshot) {
        final isGuest = snapshot.data ?? false;
        print('👥 Guest mode: $isGuest');

        if (user == null && isGuest) {
          print('🚪 Guest logged in -> MainLayout');
          return MainLayout(
            isDarkMode: themeProvider.isDarkMode,
            onThemeChanged: (newValue) {
              themeProvider.toggleDarkMode(newValue);
              repository.updateSetting(UserSettingEntity.darkTheme(newValue));
            },
          );
        }

        if (user == null) {
          print('🔐 No user, no guest -> WelcomeScreen');
          return const WelcomeScreen();
        }

        return FutureBuilder<bool>(
          future: _checkNeedsOnboarding(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (snapshot.data!) {
              print('🎓 Needs onboarding -> Welcome2Screen');
              return const Welcome2Screen();
            }

            print('✅ Logged in -> MainLayout');
            return MainLayout(
              isDarkMode: themeProvider.isDarkMode,
              onThemeChanged: (newValue) {
                themeProvider.toggleDarkMode(newValue);
                repository.updateSetting(UserSettingEntity.darkTheme(newValue));
              },
            );
          },
        );
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const MainLayout({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(5, (index) => GlobalKey<NavigatorState>());

  void _onItemTapped(int index) {
    if (index == _selectedIndex) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  void _onFavoritePressed() {
    setState(() {
      _selectedIndex = 3;
    });
  }

  void _onContactPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ContactPage()),
    );
  }

  @override
  void didUpdateWidget(MainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ensure theme is updated when the widget is updated
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      if (themeProvider.isDarkMode != widget.isDarkMode) {
        themeProvider.toggleDarkMode(widget.isDarkMode);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildNavigator(0, HomeScreen(onMealPlanPressed: () => _onItemTapped(1),
              isDarkMode: widget.isDarkMode,
              onThemeChanged: widget.onThemeChanged)),
          _buildNavigator(1, const WeekScreen()),
          _buildNavigator(2, const CreateRecipeScreen()),
          _buildNavigator(3, const FavoritesScreen()),
          _buildNavigator(4, SettingsScreen(
            onFavoritePressed: _onFavoritePressed,
            isDarkMode: widget.isDarkMode,
            onThemeChanged: widget.onThemeChanged,
          )),
        ],
      ),
      bottomNavigationBar: NavbarWidget(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildNavigator(int index, Widget screen) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => screen,
        settings: settings,
      ),
    );
  }
}