import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/book.dart';
import 'word_tokenizer.dart';

/// Handles the "books" folder where the user copies .txt files to read,
/// and scans it for available books. Mobile/desktop implementation.
class BookRepository {
  static Directory? _cachedDir;

  /// Returns the folder the user should copy .txt books into, creating it
  /// if it doesn't exist yet.
  ///
  /// - Android: app-specific external storage (visible via any file manager
  ///   under `Android/data/<package>/files/books`, no runtime permission
  ///   needed for the app's own directory).
  /// - iOS/desktop: the app's Documents folder.
  static Future<Directory> getBooksDirectory() async {
    if (_cachedDir != null) return _cachedDir!;

    final Directory base;
    if (Platform.isAndroid) {
      base = (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationDocumentsDirectory();
    }

    final booksDir = Directory('${base.path}${Platform.pathSeparator}books');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    _cachedDir = booksDir;
    return booksDir;
  }

  static Future<String?> getBooksFolderPath() async =>
      (await getBooksDirectory()).path;

  static bool get supportsManualUpload => false;

  /// Lists every .txt file found in the books folder, sorted by title.
  static Future<List<Book>> listBooks() async {
    final dir = await getBooksDirectory();
    final entries = await dir.list().toList();

    final books = entries
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.txt'))
        .map(
          (f) => Book(
            id: f.path,
            title: _titleFromPath(f.path),
            loadWords: () async =>
                WordTokenizer.tokenizeBytes(await f.readAsBytes()),
          ),
        )
        .toList();

    books.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return books;
  }

  static Future<void> addBook(String title, List<int> bytes) {
    throw UnsupportedError(
      'Il caricamento manuale dei libri è disponibile solo nella versione web.',
    );
  }

  static Future<void> deleteBook(String id) {
    throw UnsupportedError(
      'La rimozione manuale dei libri è disponibile solo nella versione web.',
    );
  }

  static String _titleFromPath(String path) {
    final name = path.split(RegExp(r'[\\/]+')).last;
    return name.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
  }
}
