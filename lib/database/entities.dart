import 'dart:convert';
import 'package:floor/floor.dart';

/// Converter to store List<String> as a JSON string
class StringListConverter extends TypeConverter<List<String>, String> {
  @override
  List<String> decode(String databaseValue) {
    final List<dynamic> jsonList = jsonDecode(databaseValue) as List<dynamic>;
    return jsonList.cast<String>();
  }

  @override
  String encode(List<String> value) {
    return jsonEncode(value);
  }
}

@Entity(tableName: 'Recipe')
@TypeConverters(const [StringListConverter])
class RecipeEntity {
  @primaryKey
  final String documentId;
  final String name;

  /// Local asset path
  final String assetPath;

  /// Optional remote URL override
  final String? imageUrl;

  final String prepTime;
  final String servings;
  final String Introduction;
  final String category;
  final String difficulty;
  final String ingredientsAmount;
  final List<String> ingredients;
  final List<String> instructions;

  RecipeEntity({
    required this.documentId,
    required this.name,
    required this.assetPath,
    this.imageUrl,
    required this.prepTime,
    required this.servings,
    required this.Introduction,
    required this.category,
    required this.difficulty,
    required this.ingredientsAmount,
    required this.ingredients,
    required this.instructions,
  });

}

// Add this to your entities.dart file

@Entity(tableName: 'FavoriteRecipe')
class FavoriteRecipeEntity {
  @primaryKey
  final String documentId;
  final bool synced;

  FavoriteRecipeEntity(this.documentId, {this.synced = false});
}

@Entity(tableName: 'UserProfile')
class UserProfileEntity {
  @primaryKey
  final String uid;
  final String name;
  final String email;

  UserProfileEntity({required this.uid, required this.name, required this.email});
}

@Entity(tableName: 'UserSettings')
class UserSettingEntity {
  @primaryKey
  final String key;
  final String value;

  UserSettingEntity(this.key, this.value);

  static const String GUEST_MODE = "guest_mode";
  static const String DARK_THEME = "dark_theme";
  static const String NOTIFICATION_ENABLED = "notification_enabled";

  factory UserSettingEntity.guestMode(bool isGuest) => UserSettingEntity(GUEST_MODE, isGuest.toString());
  factory UserSettingEntity.darkTheme(bool isDark)   => UserSettingEntity(DARK_THEME, isDark.toString());
  factory UserSettingEntity.notificationEnabled(bool enabled) =>
      UserSettingEntity(NOTIFICATION_ENABLED, enabled.toString());

  bool toBool() => value.toLowerCase() == 'true';
}
