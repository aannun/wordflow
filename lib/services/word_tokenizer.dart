import 'dart:convert';
import 'dart:typed_data';

/// Splits book text into the sequence of words shown one at a time by the
/// reader screen. Pure and platform-agnostic — mobile/desktop feeds it
/// bytes read from a file, web feeds it bytes read from the browser.
class WordTokenizer {
  static List<String> tokenizeText(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  static List<String> tokenizeBytes(Uint8List bytes) {
    return tokenizeText(decodeText(bytes));
  }

  /// Most .txt ebooks are UTF-8, but older Italian exports are often
  /// Windows-1252/Latin-1, which breaks strict UTF-8 decoding. Fall back
  /// to Latin-1 rather than showing garbled text or crashing.
  static String decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }
}
