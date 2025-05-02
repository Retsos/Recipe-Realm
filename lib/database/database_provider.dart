import 'package:reciperealm/database/app_database.dart';

class DatabaseProvider {
  static AppDatabase? _instance;

  static Future<AppDatabase> getInstance() async {
    if (_instance != null) return _instance!;
    _instance = await AppDatabase.initialize();
    return _instance!;
  }

  static Future<void> resetInstance() async {
    _instance = await AppDatabase.initialize(); // reinitialize
  }

}
