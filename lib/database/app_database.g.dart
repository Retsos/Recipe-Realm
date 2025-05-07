// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

abstract class $AppDatabaseBuilderContract {
  /// Adds migrations to the builder.
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations);

  /// Adds a database [Callback] to the builder.
  $AppDatabaseBuilderContract addCallback(Callback callback);

  /// Creates the database and initializes it.
  Future<AppDatabase> build();
}

// ignore: avoid_classes_with_only_static_members
class $FloorAppDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract databaseBuilder(String name) =>
      _$AppDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract inMemoryDatabaseBuilder() =>
      _$AppDatabaseBuilder(null);
}

class _$AppDatabaseBuilder implements $AppDatabaseBuilderContract {
  _$AppDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  @override
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  @override
  $AppDatabaseBuilderContract addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  @override
  Future<AppDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$AppDatabase();
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }
}

class _$AppDatabase extends AppDatabase {
  _$AppDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  RecipeDao? _recipeDaoInstance;

  FavoriteRecipeDao? _favoriteRecipeDaoInstance;

  UserSettingDao? _userSettingDaoInstance;

  UserProfileDao? _userProfileDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 10,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `Recipe` (`documentId` TEXT NOT NULL, `name` TEXT NOT NULL, `assetPath` TEXT NOT NULL, `imageUrl` TEXT, `prepTime` TEXT NOT NULL, `servings` TEXT NOT NULL, `Introduction` TEXT NOT NULL, `category` TEXT NOT NULL, `difficulty` TEXT NOT NULL, `ingredientsAmount` TEXT NOT NULL, `ingredients` TEXT NOT NULL, `instructions` TEXT NOT NULL, PRIMARY KEY (`documentId`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `FavoriteRecipe` (`documentId` TEXT NOT NULL, `synced` INTEGER NOT NULL, PRIMARY KEY (`documentId`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `UserSettings` (`key` TEXT NOT NULL, `value` TEXT NOT NULL, PRIMARY KEY (`key`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `UserProfile` (`uid` TEXT NOT NULL, `name` TEXT NOT NULL, `email` TEXT NOT NULL, PRIMARY KEY (`uid`))');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  RecipeDao get recipeDao {
    return _recipeDaoInstance ??= _$RecipeDao(database, changeListener);
  }

  @override
  FavoriteRecipeDao get favoriteRecipeDao {
    return _favoriteRecipeDaoInstance ??=
        _$FavoriteRecipeDao(database, changeListener);
  }

  @override
  UserSettingDao get userSettingDao {
    return _userSettingDaoInstance ??=
        _$UserSettingDao(database, changeListener);
  }

  @override
  UserProfileDao get userProfileDao {
    return _userProfileDaoInstance ??=
        _$UserProfileDao(database, changeListener);
  }
}

class _$RecipeDao extends RecipeDao {
  _$RecipeDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _recipeEntityInsertionAdapter = InsertionAdapter(
            database,
            'Recipe',
            (RecipeEntity item) => <String, Object?>{
                  'documentId': item.documentId,
                  'name': item.name,
                  'assetPath': item.assetPath,
                  'imageUrl': item.imageUrl,
                  'prepTime': item.prepTime,
                  'servings': item.servings,
                  'Introduction': item.Introduction,
                  'category': item.category,
                  'difficulty': item.difficulty,
                  'ingredientsAmount': item.ingredientsAmount,
                  'ingredients': _stringListConverter.encode(item.ingredients),
                  'instructions': _stringListConverter.encode(item.instructions)
                }),
        _recipeEntityUpdateAdapter = UpdateAdapter(
            database,
            'Recipe',
            ['documentId'],
            (RecipeEntity item) => <String, Object?>{
                  'documentId': item.documentId,
                  'name': item.name,
                  'assetPath': item.assetPath,
                  'imageUrl': item.imageUrl,
                  'prepTime': item.prepTime,
                  'servings': item.servings,
                  'Introduction': item.Introduction,
                  'category': item.category,
                  'difficulty': item.difficulty,
                  'ingredientsAmount': item.ingredientsAmount,
                  'ingredients': _stringListConverter.encode(item.ingredients),
                  'instructions': _stringListConverter.encode(item.instructions)
                }),
        _recipeEntityDeletionAdapter = DeletionAdapter(
            database,
            'Recipe',
            ['documentId'],
            (RecipeEntity item) => <String, Object?>{
                  'documentId': item.documentId,
                  'name': item.name,
                  'assetPath': item.assetPath,
                  'imageUrl': item.imageUrl,
                  'prepTime': item.prepTime,
                  'servings': item.servings,
                  'Introduction': item.Introduction,
                  'category': item.category,
                  'difficulty': item.difficulty,
                  'ingredientsAmount': item.ingredientsAmount,
                  'ingredients': _stringListConverter.encode(item.ingredients),
                  'instructions': _stringListConverter.encode(item.instructions)
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<RecipeEntity> _recipeEntityInsertionAdapter;

  final UpdateAdapter<RecipeEntity> _recipeEntityUpdateAdapter;

  final DeletionAdapter<RecipeEntity> _recipeEntityDeletionAdapter;

  @override
  Future<List<RecipeEntity>> findAllRecipes() async {
    return _queryAdapter.queryList('SELECT * FROM Recipe',
        mapper: (Map<String, Object?> row) => RecipeEntity(
            documentId: row['documentId'] as String,
            name: row['name'] as String,
            assetPath: row['assetPath'] as String,
            imageUrl: row['imageUrl'] as String?,
            prepTime: row['prepTime'] as String,
            servings: row['servings'] as String,
            Introduction: row['Introduction'] as String,
            category: row['category'] as String,
            difficulty: row['difficulty'] as String,
            ingredientsAmount: row['ingredientsAmount'] as String,
            ingredients:
                _stringListConverter.decode(row['ingredients'] as String),
            instructions:
                _stringListConverter.decode(row['instructions'] as String)));
  }

  @override
  Future<RecipeEntity?> findRecipeById(String id) async {
    return _queryAdapter.query('SELECT * FROM Recipe WHERE documentId = ?1',
        mapper: (Map<String, Object?> row) => RecipeEntity(
            documentId: row['documentId'] as String,
            name: row['name'] as String,
            assetPath: row['assetPath'] as String,
            imageUrl: row['imageUrl'] as String?,
            prepTime: row['prepTime'] as String,
            servings: row['servings'] as String,
            Introduction: row['Introduction'] as String,
            category: row['category'] as String,
            difficulty: row['difficulty'] as String,
            ingredientsAmount: row['ingredientsAmount'] as String,
            ingredients:
                _stringListConverter.decode(row['ingredients'] as String),
            instructions:
                _stringListConverter.decode(row['instructions'] as String)),
        arguments: [id]);
  }

  @override
  Future<List<RecipeEntity>> searchRecipes(String searchTerm) async {
    return _queryAdapter.queryList(
        'SELECT *      FROM Recipe      WHERE LOWER(name) LIKE \'%\' || LOWER(?1) || \'%\'',
        mapper: (Map<String, Object?> row) => RecipeEntity(documentId: row['documentId'] as String, name: row['name'] as String, assetPath: row['assetPath'] as String, imageUrl: row['imageUrl'] as String?, prepTime: row['prepTime'] as String, servings: row['servings'] as String, Introduction: row['Introduction'] as String, category: row['category'] as String, difficulty: row['difficulty'] as String, ingredientsAmount: row['ingredientsAmount'] as String, ingredients: _stringListConverter.decode(row['ingredients'] as String), instructions: _stringListConverter.decode(row['instructions'] as String)),
        arguments: [searchTerm]);
  }

  @override
  Future<List<RecipeEntity>> findFavoriteRecipes() async {
    return _queryAdapter.queryList(
        'SELECT Recipe.*        FROM Recipe        INNER JOIN FavoriteRecipe          ON Recipe.documentId = FavoriteRecipe.documentId',
        mapper: (Map<String, Object?> row) => RecipeEntity(
            documentId: row['documentId'] as String,
            name: row['name'] as String,
            assetPath: row['assetPath'] as String,
            imageUrl: row['imageUrl'] as String?,
            prepTime: row['prepTime'] as String,
            servings: row['servings'] as String,
            Introduction: row['Introduction'] as String,
            category: row['category'] as String,
            difficulty: row['difficulty'] as String,
            ingredientsAmount: row['ingredientsAmount'] as String,
            ingredients:
                _stringListConverter.decode(row['ingredients'] as String),
            instructions:
                _stringListConverter.decode(row['instructions'] as String)));
  }

  @override
  Future<void> insertRecipe(RecipeEntity recipe) async {
    await _recipeEntityInsertionAdapter.insert(
        recipe, OnConflictStrategy.abort);
  }

  @override
  Future<void> updateRecipe(RecipeEntity recipe) async {
    await _recipeEntityUpdateAdapter.update(recipe, OnConflictStrategy.abort);
  }

  @override
  Future<void> deleteRecipe(RecipeEntity recipe) async {
    await _recipeEntityDeletionAdapter.delete(recipe);
  }
}

class _$FavoriteRecipeDao extends FavoriteRecipeDao {
  _$FavoriteRecipeDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _favoriteRecipeEntityInsertionAdapter = InsertionAdapter(
            database,
            'FavoriteRecipe',
            (FavoriteRecipeEntity item) => <String, Object?>{
                  'documentId': item.documentId,
                  'synced': item.synced ? 1 : 0
                }),
        _favoriteRecipeEntityDeletionAdapter = DeletionAdapter(
            database,
            'FavoriteRecipe',
            ['documentId'],
            (FavoriteRecipeEntity item) => <String, Object?>{
                  'documentId': item.documentId,
                  'synced': item.synced ? 1 : 0
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<FavoriteRecipeEntity>
      _favoriteRecipeEntityInsertionAdapter;

  final DeletionAdapter<FavoriteRecipeEntity>
      _favoriteRecipeEntityDeletionAdapter;

  @override
  Future<void> deleteAllFavorites() async {
    await _queryAdapter.queryNoReturn('DELETE FROM FavoriteRecipe');
  }

  @override
  Future<List<FavoriteRecipeEntity>> findAllFavorites() async {
    return _queryAdapter.queryList('SELECT * FROM FavoriteRecipe',
        mapper: (Map<String, Object?> row) => FavoriteRecipeEntity(
            row['documentId'] as String,
            synced: (row['synced'] as int) != 0));
  }

  @override
  Future<FavoriteRecipeEntity?> findFavorite(String id) async {
    return _queryAdapter.query(
        'SELECT * FROM FavoriteRecipe WHERE documentId = ?1',
        mapper: (Map<String, Object?> row) => FavoriteRecipeEntity(
            row['documentId'] as String,
            synced: (row['synced'] as int) != 0),
        arguments: [id]);
  }

  @override
  Future<void> markSynced(String id) async {
    await _queryAdapter.queryNoReturn(
        'UPDATE FavoriteRecipe SET synced = 1 WHERE documentId = ?1',
        arguments: [id]);
  }

  @override
  Future<void> insertFavorite(FavoriteRecipeEntity fav) async {
    await _favoriteRecipeEntityInsertionAdapter.insert(
        fav, OnConflictStrategy.abort);
  }

  @override
  Future<void> deleteFavorite(FavoriteRecipeEntity fav) async {
    await _favoriteRecipeEntityDeletionAdapter.delete(fav);
  }
}

class _$UserSettingDao extends UserSettingDao {
  _$UserSettingDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _userSettingEntityInsertionAdapter = InsertionAdapter(
            database,
            'UserSettings',
            (UserSettingEntity item) =>
                <String, Object?>{'key': item.key, 'value': item.value}),
        _userSettingEntityUpdateAdapter = UpdateAdapter(
            database,
            'UserSettings',
            ['key'],
            (UserSettingEntity item) =>
                <String, Object?>{'key': item.key, 'value': item.value}),
        _userSettingEntityDeletionAdapter = DeletionAdapter(
            database,
            'UserSettings',
            ['key'],
            (UserSettingEntity item) =>
                <String, Object?>{'key': item.key, 'value': item.value});

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<UserSettingEntity> _userSettingEntityInsertionAdapter;

  final UpdateAdapter<UserSettingEntity> _userSettingEntityUpdateAdapter;

  final DeletionAdapter<UserSettingEntity> _userSettingEntityDeletionAdapter;

  @override
  Future<List<UserSettingEntity>> findAllSettings() async {
    return _queryAdapter.queryList('SELECT * FROM UserSettings',
        mapper: (Map<String, Object?> row) =>
            UserSettingEntity(row['key'] as String, row['value'] as String));
  }

  @override
  Future<UserSettingEntity?> findSetting(String key) async {
    return _queryAdapter.query('SELECT * FROM UserSettings WHERE key = ?1',
        mapper: (Map<String, Object?> row) =>
            UserSettingEntity(row['key'] as String, row['value'] as String),
        arguments: [key]);
  }

  @override
  Future<void> insertOrUpdateSetting(UserSettingEntity setting) async {
    await _userSettingEntityInsertionAdapter.insert(
        setting, OnConflictStrategy.replace);
  }

  @override
  Future<void> insertSetting(UserSettingEntity setting) async {
    await _userSettingEntityInsertionAdapter.insert(
        setting, OnConflictStrategy.abort);
  }

  @override
  Future<void> updateSetting(UserSettingEntity setting) async {
    await _userSettingEntityUpdateAdapter.update(
        setting, OnConflictStrategy.abort);
  }

  @override
  Future<void> deleteSetting(UserSettingEntity setting) async {
    await _userSettingEntityDeletionAdapter.delete(setting);
  }
}

class _$UserProfileDao extends UserProfileDao {
  _$UserProfileDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _userProfileEntityInsertionAdapter = InsertionAdapter(
            database,
            'UserProfile',
            (UserProfileEntity item) => <String, Object?>{
                  'uid': item.uid,
                  'name': item.name,
                  'email': item.email
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<UserProfileEntity> _userProfileEntityInsertionAdapter;

  @override
  Future<UserProfileEntity?> findProfile(String uid) async {
    return _queryAdapter.query('SELECT * FROM UserProfile WHERE uid = ?1',
        mapper: (Map<String, Object?> row) => UserProfileEntity(
            uid: row['uid'] as String,
            name: row['name'] as String,
            email: row['email'] as String),
        arguments: [uid]);
  }

  @override
  Future<void> clearProfiles() async {
    await _queryAdapter.queryNoReturn('DELETE FROM UserProfile');
  }

  @override
  Future<void> upsertProfile(UserProfileEntity profile) async {
    await _userProfileEntityInsertionAdapter.insert(
        profile, OnConflictStrategy.replace);
  }
}

// ignore_for_file: unused_element
final _stringListConverter = StringListConverter();
