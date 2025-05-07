import 'package:floor/floor.dart';
import 'entities.dart';

@dao
abstract class RecipeDao {
  @Query('SELECT * FROM Recipe')
  Future<List<RecipeEntity>> findAllRecipes();

  @Query('SELECT * FROM Recipe WHERE documentId = :id')
  Future<RecipeEntity?> findRecipeById(String id);

  @insert
  Future<void> insertRecipe(RecipeEntity recipe);

  @update
  Future<void> updateRecipe(RecipeEntity recipe);

  @delete
  Future<void> deleteRecipe(RecipeEntity recipe);

  @Query('''
    SELECT * 
    FROM Recipe 
    WHERE LOWER(name) LIKE '%' || LOWER(:searchTerm) || '%'
  ''')
  Future<List<RecipeEntity>> searchRecipes(String searchTerm);

  @Query(r'''
    SELECT Recipe.* 
      FROM Recipe 
      INNER JOIN FavoriteRecipe 
        ON Recipe.documentId = FavoriteRecipe.documentId
  ''')
  Future<List<RecipeEntity>> findFavoriteRecipes();

}

@dao
abstract class UserProfileDao {
  @Query('SELECT * FROM UserProfile WHERE uid = :uid')
  Future<UserProfileEntity?> findProfile(String uid);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> upsertProfile(UserProfileEntity profile);

  @Query('DELETE FROM UserProfile')
  Future<void> clearProfiles();
}

@dao
abstract class FavoriteRecipeDao {
  @Query('DELETE FROM FavoriteRecipe')
  Future<void> deleteAllFavorites();

  @Query('SELECT * FROM FavoriteRecipe')
  Future<List<FavoriteRecipeEntity>> findAllFavorites();

  @Query('SELECT * FROM FavoriteRecipe WHERE documentId = :id')
  Future<FavoriteRecipeEntity?> findFavorite(String id);

  @insert
  Future<void> insertFavorite(FavoriteRecipeEntity fav);

  @delete
  Future<void> deleteFavorite(FavoriteRecipeEntity fav);

  @Query('UPDATE FavoriteRecipe SET synced = 1 WHERE documentId = :id')
  Future<void> markSynced(String id);


}

@dao
abstract class UserSettingDao {
  @Query('SELECT * FROM UserSettings')
  Future<List<UserSettingEntity>> findAllSettings();

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertOrUpdateSetting(UserSettingEntity setting);

  @Query('SELECT * FROM UserSettings WHERE key = :key')
  Future<UserSettingEntity?> findSetting(String key);

  @insert
  Future<void> insertSetting(UserSettingEntity setting);

  @update
  Future<void> updateSetting(UserSettingEntity setting);

  @delete
  Future<void> deleteSetting(UserSettingEntity setting);
}
