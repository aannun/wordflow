import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores books directly in the browser (via shared_preferences, backed by
/// localStorage on web) — no server, no accounts, everything lives in this
/// one browser profile. Fine for a personal library of a handful of books;
/// a very large collection could bump into the browser's local storage
/// quota (commonly a few MB per site).
class WebBookStore {
  static const _indexKey = 'web_books_index';

  static Future<List<WebBookEntry>> listAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(WebBookEntry.fromJson).toList();
  }

  static Future<String> add(String title, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await prefs.setString(_textKey(id), text);

    final entries = await listAll()
      ..add(WebBookEntry(id: id, title: title));
    await _saveIndex(prefs, entries);

    return id;
  }

  static Future<String> readText(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_textKey(id)) ?? '';
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_textKey(id));

    final entries = await listAll()..removeWhere((e) => e.id == id);
    await _saveIndex(prefs, entries);
  }

  static Future<void> _saveIndex(
    SharedPreferences prefs,
    List<WebBookEntry> entries,
  ) {
    return prefs.setString(
      _indexKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  static String _textKey(String id) => 'web_book_text_$id';
}

class WebBookEntry {
  final String id;
  final String title;

  const WebBookEntry({required this.id, required this.title});

  factory WebBookEntry.fromJson(Map<String, dynamic> json) =>
      WebBookEntry(id: json['id'] as String, title: json['title'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'title': title};
}
