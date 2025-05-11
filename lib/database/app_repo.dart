  import 'dart:async';
  import 'dart:io';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:connectivity_plus/connectivity_plus.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/foundation.dart';
  import 'package:flutter/material.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:sqflite/sqflite.dart' as sqflite;

  import 'app_database.dart';
  import 'database_provider.dart';
  import 'entities.dart';

  class AppRepository extends ChangeNotifier {
    AppDatabase get localDb => _localDb!;
    AppDatabase? _localDb;

    final FirebaseFirestore firestore;
    final Connectivity connectivity;
    String? _userId;

    // Controllers for state management
    final _favoritesChangedController = StreamController<void>.broadcast();
    Stream<void> get favoritesChanged => _favoritesChangedController.stream;

    AppRepository({
      required AppDatabase localDb,
      required this.firestore,
      required this.connectivity,
    }) {
      _localDb = localDb;
      debugPrint('[AppRepository] 🔄 constructor — localDb ready, firestore ready, connectivity ready');
    }

    Future<void> reinitializeDatabase() async {
      debugPrint('[AppRepository] 🔁 Resetting local database instance');
      _localDb = await DatabaseProvider.getInstance();
    }


    /// Checks database version and table structure
    Future<void> _checkDatabaseStructure() async {
      // Check database version
      // await AppDatabase.checkCurrentDatabaseVersion();

      // Check if user profile table exists
      final dbPath = await sqflite.getDatabasesPath();
      final path = '$dbPath/app_database.db';

      if (await sqflite.databaseExists(path)) {
        final db = await sqflite.openDatabase(path);
        try {
          // Check if UserProfile table exists
          final tables = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='UserProfile'");
          debugPrint("User profile table exists: ${tables.isNotEmpty}");

          // Check all tables in the database
          final allTables = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table'");
          debugPrint("All tables in database: ${allTables.map((t) => t['name']).toList()}");

          // Try to query the user profile table to check its structure
          try {
            final columns = await db.rawQuery('PRAGMA table_info(UserProfile)');
            debugPrint("User profile table columns: $columns");
          } catch (e) {
            debugPrint("Error querying UserProfile table structure: $e");
          }
        } catch (e) {
          debugPrint("Error checking database structure: $e");
        } finally {
          await db.close();
        }
      } else {
        debugPrint("Database doesn't exist yet");
      }
    }

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

    Future<bool> isUserLoggedIn() async {
      final user = FirebaseAuth.instance.currentUser;
      return user != null;
    }
    /// Must be called once after user signs in
    Future<void> initializeForUser(String userId) async {
      _userId = userId;
      await Future.wait([
        _pullFavoritesFromCloud(),
        _pullUserProfileFromCloud(),
      ]);
    }

    // Recipes
    Future<List<RecipeEntity>> getRecipes() =>
        localDb.recipeDao.findAllRecipes();
    Future<RecipeEntity?> getRecipe(String id) =>
        localDb.recipeDao.findRecipeById(id);

    // Favorites (local-first)
    Future<List<FavoriteRecipeEntity>> getFavorites() async =>
        localDb.favoriteRecipeDao.findAllFavorites();

    Future<bool> isFavorite(String recipeId) async {
      final favorite = await localDb.favoriteRecipeDao.findFavorite(recipeId);
      return favorite != null;
    }
    void setDatabase(AppDatabase newDb) {
      debugPrint('[AppRepository] 🔁 Resetting local database instance');
      _localDb = newDb;
    }
    static DateTime? _lastSnackbarTime;

    Future<void> toggleFavorite(BuildContext context, String recipeId, bool isFavorite) async {
      final dao = localDb.favoriteRecipeDao;

      // 1) Απόφυγη σπαμ SnackBar
      final now = DateTime.now();
      if (_lastSnackbarTime != null
          && now.difference(_lastSnackbarTime!).inMilliseconds < 2500) {
        // skip
      }
      _lastSnackbarTime = now;

      // 2) Guest check
      if (!(await isUserLoggedIn())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must login to save favorites!')),
        );
        return;
      }

      // 3) Τοπικό write πάντως, synced=false
      if (isFavorite) {
        await dao.insertFavorite(FavoriteRecipeEntity(recipeId, synced: false));
      } else {
        final fav = await dao.findFavorite(recipeId);
        if (fav != null) await dao.deleteFavorite(fav);
      }
      notifyFavoritesChanged();

      if (await _hasRealInternet()) {
        final all = await dao.findAllFavorites();
        final ids = all.map((f) => f.documentId).toList();
        final uid = _userId ?? FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await firestore
              .collection('User')
              .doc(uid)
              .set({'favorites': ids}, SetOptions(merge: true));

          for (var f in all) {
            await dao.markSynced(f.documentId);
          }
          notifyFavoritesChanged();
        }
      } else {
        ///ΑΠΟΦΥΓΗ ΣΠΑΜ

        // Αν έχει περάσει λιγότερο από 2.5 δευτερόλ  επτα, δεν δειχνω νέο Snackbar
        if (_lastSnackbarTime != null &&
            now.difference(_lastSnackbarTime!).inMilliseconds < 2500) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(
            content: Text('Offline: Favorites will sync when back online!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    Future<void> addFavoriteRecipe(String recipeId) async {
      if (!(await isUserLoggedIn())) {
        debugPrint('[Favorites] Cannot add favorite - user not logged in');
        return; // Exit early
      }

      final dao = localDb.favoriteRecipeDao;
      final existing = await dao.findFavorite(recipeId);

      if (existing == null) {
        debugPrint('[Favorites] Adding new recipe $recipeId to favorites');
        await dao.insertFavorite(FavoriteRecipeEntity(recipeId, synced: false));

        // Log all local favorites after addition
        final localFavorites = await dao.findAllFavorites();
        debugPrint('[Favorites] Updated local favorites: ${localFavorites.map((f) => f.documentId).toList()}');

        // If user is logged in, sync with Firestore
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && await _isConnected) {
          try {
            await _syncFavorites();
            debugPrint('[Favorites] Synchronized with Firestore');
          } catch (e) {
            debugPrint('[Favorites] Error syncing with Firestore: $e');
          }
        }

        // Notify listeners
        notifyFavoritesChanged();
      } else {
        debugPrint('[Favorites] Recipe $recipeId already in favorites');
      }
    }

    Future<void> removeFavoriteRecipe(String recipeId) async {
      if (!(await isUserLoggedIn())) {
        debugPrint('[Favorites] Cannot remove favorite - user not logged in');
        return; // Exit early
      }

      final dao = localDb.favoriteRecipeDao;
      final existing = await dao.findFavorite(recipeId);

      if (existing != null) {
        debugPrint('[Favorites] Removing recipe $recipeId from favorites');
        await dao.deleteFavorite(existing);

        // Log all local favorites after removal
        final localFavorites = await dao.findAllFavorites();
        debugPrint('[Favorites] Updated local favorites: ${localFavorites.map((f) => f.documentId).toList()}');

        // If user is logged in, sync with Firestore
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && await _isConnected) {
          try {
            await _syncFavorites();
            debugPrint('[Favorites] Synchronized with Firestore');
          } catch (e) {
            debugPrint('[Favorites] Error syncing with Firestore: $e');
          }
        }

        // Notify listeners
        notifyFavoritesChanged();
      } else {
        debugPrint('[Favorites] Recipe $recipeId not found in favorites');
      }
    }

    /// Returns true if device is currently online
    Future<bool> isConnected() => _isConnected;

    /// Pushes any pending favorites to Firestore and pulls latest from cloud
    Future<void> syncFavorites() async {
      if (!(await isUserLoggedIn())) {
        debugPrint('[Favorites] Cannot sync favorites - user not logged in');
        return; // Exit early
      }

      if (!await _isConnected) {
        debugPrint('[Favorites] Can\'t sync - no connection');
        return;
      }

      debugPrint('[Favorites] Syncing favorites - pulling from cloud first');
      await _pullFavoritesFromCloud();
      debugPrint('[Favorites] Syncing favorites - pushing local changes');
      await _syncFavorites();
    }

    /// Notifies listeners that favorites state has changed
    void notifyFavoritesChanged() {
      _favoritesChangedController.add(null);
      notifyListeners();
    }

    /// Read local profile
    Future<UserProfileEntity?> getLocalProfile() {
      if (_userId == null) return Future.value(null);
      return localDb.userProfileDao.findProfile(_userId!);
    }

    Future<void> _pullUserProfileFromCloud() async {
      if (_userId == null) return;
      final doc = await firestore.collection('User').doc(_userId).get();
      final data = doc.data();
      if (data == null) return;
      final profile = UserProfileEntity(
        uid: _userId!,
        name: data['name'] as String? ?? '',
        email: data['email'] as String? ?? '',
      );
      await localDb.userProfileDao.upsertProfile(profile);
    }

    Future<void> saveLocalProfile(UserProfileEntity profile) async {
      await localDb.userProfileDao.upsertProfile(profile);
    }

    Future<void> clearUserData() async {
      debugPrint('[AppRepository] 🔄 clearUserData() — wiping local DB & prefs');
      _userId = null;
      await localDb.userProfileDao.clearProfiles();
      await localDb.favoriteRecipeDao.deleteAllFavorites();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('[AppRepository] ✅ all local data cleared');
    }

    // Settings
    Future<UserSettings> getSettings() async {
      final settings = await localDb.userSettingDao.findAllSettings();
      return UserSettings(
        isGuest:
        _getBoolSetting(settings, UserSettingEntity.GUEST_MODE) ?? true,
        darkTheme:
        _getBoolSetting(settings, UserSettingEntity.DARK_THEME) ?? false,
      );
    }

    Future<void> updateSetting(UserSettingEntity setting) async {
      try {
        await localDb.userSettingDao.insertOrUpdateSetting(setting);
        debugPrint("[Settings] Successfully updated setting: ${setting.key} = ${setting.value}");
      } catch (e) {
        debugPrint("[Settings] Error updating setting ${setting.key}: $e");
        // If the insertOrUpdateSetting fails for some reason, fall back to the old approach
        // with additional error handling
        try {
          final existing = await localDb.userSettingDao.findSetting(setting.key);
          if (existing == null) {
            debugPrint("[Settings] No existing setting found, inserting new setting");
            await localDb.userSettingDao.insertSetting(setting);
          } else {
            debugPrint("[Settings] Existing setting found, updating");
            await localDb.userSettingDao.updateSetting(setting);
          }
        } catch (fallbackError) {
          debugPrint("[Settings] Fallback approach also failed: $fallbackError");
          throw fallbackError; // Re-throw to let the caller know there was an issue
        }
      }
    }

    // === Internal Sync logic ===
    Future<void> _syncFavorites() async {
      if (!await _isConnected) {
        debugPrint('[Favorites] Can\'t sync - no connection');
        return;
      }

      final uid = _userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('[Favorites] Can\'t sync - no user ID');
        return;
      }

      final dao = localDb.favoriteRecipeDao;
      final unsynced = (await dao.findAllFavorites())
          .where((f) => !f.synced)
          .toList();

      debugPrint('[Favorites] Found ${unsynced.length} unsynced favorites');

      if (unsynced.isEmpty) return;

      // Get all favorites to update the array in Firestore
      final allFavorites = await dao.findAllFavorites();
      final favoriteIds = allFavorites.map((f) => f.documentId).toList();

      debugPrint('[Favorites] Updating Firestore with favorites: $favoriteIds');

      try {
        // Update the favorites array in the user document
        await firestore.collection('User').doc(uid).update({
          'favorites': favoriteIds,
        });

        // Mark all as synced
        for (var fav in unsynced) {
          await dao.markSynced(fav.documentId);
        }

        debugPrint('[Favorites] Successfully synced favorites to Firestore');
      } catch (e) {
        debugPrint('[Favorites] Error syncing favorites to Firestore: $e');

        // If the document doesn't exist, create it
        if (e is FirebaseException && e.code == 'not-found') {
          debugPrint('[Favorites] User document not found, creating it');
          try {
            await firestore.collection('User').doc(uid).set({
              'favorites': favoriteIds,
              'createdAt': FieldValue.serverTimestamp(),
            });

            // Mark all as synced
            for (var fav in unsynced) {
              await dao.markSynced(fav.documentId);
            }

            debugPrint('[Favorites] Successfully created user document with favorites');
          } catch (e2) {
            debugPrint('[Favorites] Error creating user document: $e2');
          }
        }
      }
    }

    Future<void> _pullFavoritesFromCloud() async {
      final uid = _userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('[Favorites] Can\'t pull from cloud - no user ID');
        return;
      }

      debugPrint('[Favorites] Pulling favorites from cloud for user $uid');

      final dao = localDb.favoriteRecipeDao;

      try {
        final userDoc = await firestore.collection('User').doc(uid).get();
        final userData = userDoc.data();

        // Get the favorites array from the user document
        List<String> cloudFavorites = [];
        if (userData != null && userData.containsKey('favorites')) {
          cloudFavorites = List<String>.from(userData['favorites'] ?? []);
        }

        debugPrint('[Favorites] Found ${cloudFavorites.length} favorites in cloud: $cloudFavorites');

        // Get current local favorites
        final localFavorites = await dao.findAllFavorites();
        final localFavoriteIds = localFavorites.map((f) => f.documentId).toList();

        debugPrint('[Favorites] Current local favorites: $localFavoriteIds');

        // Only replace if there's a difference
        if (!(cloudFavorites.length == localFavoriteIds.length &&
            cloudFavorites.every((id) => localFavoriteIds.contains(id)))) {

          debugPrint('[Favorites] Difference detected, updating local favorites');

          // Clear local favorites
          for (var f in localFavorites) await dao.deleteFavorite(f);

          // Insert cloud favorites as synced
          for (var recipeId in cloudFavorites) {
            await dao.insertFavorite(
              FavoriteRecipeEntity(recipeId, synced: true),
            );
          }

          debugPrint('[Favorites] Local favorites updated from cloud');
          notifyFavoritesChanged();
        } else {
          debugPrint('[Favorites] Local favorites already match cloud, no update needed');
        }
      } catch (e) {
        debugPrint('[Favorites] Error pulling favorites from cloud: $e');
      }
    }

    Future<bool> get _isConnected async {
      final result = await connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    }

    /// Listen for network changes
    void startSyncListener() {
      connectivity.onConnectivityChanged.listen((result) async {
        if (result != ConnectivityResult.none) {
          debugPrint('[Favorites] Network connectivity restored, syncing favorites');
          await _syncFavorites();
        }
      });
    }

    @override
    void dispose() {
      _favoritesChangedController.close();
      super.dispose();
    }

    // Helper for parsing bools
    bool? _getBoolSetting(List<UserSettingEntity> settings, String key) {
      try {
        return settings
            .firstWhere((s) => s.key == key)
            .toBool();
      } catch (_) {
        return null;
      }
    }
  }

  class UserSettings {
    final bool isGuest;
    final bool darkTheme;

    UserSettings({required this.isGuest, required this.darkTheme});
  }