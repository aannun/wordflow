import 'dart:typed_data';

import '../models/book.dart';
import 'web_book_store.dart';
import 'word_tokenizer.dart';

/// Books stored directly in the browser (via [WebBookStore]) — web
/// implementation. There's no filesystem folder to scan, so books are
/// added manually through the library screen's upload button instead.
class BookRepository {
  static Future<String?> getBooksFolderPath() async => null;

  static bool get supportsManualUpload => true;

  static Future<List<Book>> listBooks() async {
    final entries = await WebBookStore.listAll();

    final books = entries
        .map(
          (e) => Book(
            id: e.id,
            title: e.title,
            loadWords: () async =>
                WordTokenizer.tokenizeText(await WebBookStore.readText(e.id)),
          ),
        )
        .toList();

    books.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return books;
  }

  static Future<void> addBook(String title, List<int> bytes) async {
    final text = WordTokenizer.decodeText(Uint8List.fromList(bytes));
    await WebBookStore.add(title, text);
  }

  static Future<void> deleteBook(String id) => WebBookStore.delete(id);
}
