import 'dart:typed_data';

import 'pdf_book_extractor.dart';
import 'word_tokenizer.dart';

/// Filename helpers shared by every book source (folder scan, bundled
/// assets, browser uploads) so extension checks and title-stripping stay
/// consistent in one place.
const supportedBookExtensions = ['.txt', '.pdf'];

bool isPdfFilename(String filename) => filename.toLowerCase().endsWith('.pdf');

bool isSupportedBookFilename(String filename) {
  final lower = filename.toLowerCase();
  return supportedBookExtensions.any(lower.endsWith);
}

String titleFromFilename(String filename) {
  final name = filename.split(RegExp(r'[\\/]+')).last;
  return name.replaceAll(RegExp(r'\.(txt|pdf)$', caseSensitive: false), '');
}

/// Turns raw file bytes into readable text, dispatching to PDF extraction
/// or plain-text decoding based on the filename's extension.
String textFromBookBytes(Uint8List bytes, String filename) {
  if (isPdfFilename(filename)) {
    return PdfBookExtractor.extractCleanText(bytes);
  }
  return WordTokenizer.decodeText(bytes);
}
