import 'package:flutter/services.dart';

import '../models/book.dart';
import 'word_tokenizer.dart';

/// Books shipped with the app itself (assets/books/*.txt), available on
/// every device without needing to be re-added. Uses Flutter's asset
/// bundle, which works identically on every platform — no conditional
/// import needed here, unlike the per-device book storage.
class BundledBookRepository {
  static const _prefix = 'assets/books/';

  static Future<List<Book>> listBooks() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest.listAssets().where(
      (k) => k.startsWith(_prefix) && k.toLowerCase().endsWith('.txt'),
    );

    final books = paths.map((path) {
      final name = path.substring(_prefix.length);
      final title = name.replaceAll(
        RegExp(r'\.txt$', caseSensitive: false),
        '',
      );
      return Book(
        id: 'bundled:$path',
        title: title,
        removable: false,
        loadWords: () async {
          final data = await rootBundle.load(path);
          return WordTokenizer.tokenizeBytes(data.buffer.asUint8List());
        },
      );
    }).toList();

    books.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return books;
  }
}
