import 'dart:typed_data';

import '../models/book.dart';
import 'book_format.dart';
import 'bundled_book_repository.dart';
import 'web_book_store.dart';
import 'word_tokenizer.dart';

/// Books stored directly in the browser (via [WebBookStore]), plus the
/// books bundled with the app — web implementation. There's no filesystem
/// folder to scan, so uploaded books are added manually through the
/// library screen's upload button instead.
class BookRepository {
  static Future<String?> getBooksFolderPath() async => null;

  static bool get supportsManualUpload => true;

  static Future<List<Book>> listBooks() async {
    final entries = await WebBookStore.listAll();

    final ownBooks = entries.map(
      (e) => Book(
        id: e.id,
        title: e.title,
        removable: true,
        loadWords: () async =>
            WordTokenizer.tokenizeText(await WebBookStore.readText(e.id)),
      ),
    );

    final bundled = await BundledBookRepository.listBooks();
    final books = [...bundled, ...ownBooks];

    books.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return books;
  }

  /// [filename] is the original picked filename (with extension) — needed
  /// to tell a .pdf from a .txt upload; the display title is derived from
  /// it here.
  static Future<void> addBook(String filename, List<int> bytes) async {
    final title = titleFromFilename(filename);
    final text = textFromBookBytes(Uint8List.fromList(bytes), filename);
    await WebBookStore.add(title, text);
  }

  static Future<void> deleteBook(String id) => WebBookStore.delete(id);
}
