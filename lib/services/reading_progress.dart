import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, per book, the index of the last word shown so reading can
/// resume where it left off after leaving and reopening the app.
class ReadingProgressStore {
  static String _key(String bookPath) => 'progress_$bookPath';

  static Future<int> load(String bookPath) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(bookPath)) ?? 0;
  }

  static Future<void> save(String bookPath, int wordIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(bookPath), wordIndex);
  }

  static Future<void> clear(String bookPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(bookPath));
  }
}
