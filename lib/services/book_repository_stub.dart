import '../models/book.dart';
import 'bundled_book_repository.dart';

/// Fallback for platforms that are neither dart:io nor web. Should never
/// actually be selected by Flutter's supported build targets.
class BookRepository {
  static Future<String?> getBooksFolderPath() async => null;

  static bool get supportsManualUpload => false;

  static Future<List<Book>> listBooks() => BundledBookRepository.listBooks();

  static Future<void> addBook(String title, List<int> bytes) {
    throw UnsupportedError('Not supported on this platform.');
  }

  static Future<void> deleteBook(String id) {
    throw UnsupportedError('Not supported on this platform.');
  }
}
