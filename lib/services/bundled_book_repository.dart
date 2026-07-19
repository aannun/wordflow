import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../models/book.dart';
import 'book_format.dart';
import 'web_book_store.dart';
import 'word_tokenizer.dart';

/// Books shipped with the app itself (assets/books/*.txt or *.pdf),
/// available on every device without needing to be re-added. Uses
/// Flutter's asset bundle, which works identically on every platform — no
/// conditional import needed here, unlike the per-device book storage.
///
/// On web specifically, the app doesn't precache these upfront (see the
/// `--pwa-strategy=none` build flag): a book's text is only fetched (and,
/// for PDFs, extracted) the first time it's actually opened, then cached
/// in the browser so it stays readable offline afterwards. [WebBookStore]
/// (backed by localStorage) is safe to use on every platform, so no
/// conditional import is needed for that either — it's simply only
/// exercised when [kIsWeb] is true.
class BundledBookRepository {
  static const _prefix = 'assets/books/';

  static Future<List<Book>> listBooks() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest.listAssets().where(
      (k) => k.startsWith(_prefix) && isSupportedBookFilename(k),
    );

    final books = paths.map((path) {
      final title = titleFromFilename(path);
      final id = 'bundled:$path';
      return Book(
        id: id,
        title: title,
        removable: false,
        loadWords: () => kIsWeb
            ? _loadWebCached(id: id, path: path, title: title)
            : _loadDirect(path),
      );
    }).toList();

    books.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return books;
  }

  static Future<List<String>> _loadDirect(String path) async {
    final data = await rootBundle.load(path);
    final text = textFromBookBytes(data.buffer.asUint8List(), path);
    return WordTokenizer.tokenizeText(text);
  }

  static Future<List<String>> _loadWebCached({
    required String id,
    required String path,
    required String title,
  }) async {
    final cached = await WebBookStore.readCachedBundledText(id);
    if (cached != null) {
      return WordTokenizer.tokenizeText(cached);
    }

    final String text;
    try {
      final data = await rootBundle.load(path);
      text = textFromBookBytes(data.buffer.asUint8List(), path);
    } catch (_) {
      throw BookUnavailableOfflineException(title);
    }

    await WebBookStore.cacheBundledText(id, text);
    return WordTokenizer.tokenizeText(text);
  }
}
