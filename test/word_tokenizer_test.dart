import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wordflow/services/word_tokenizer.dart';

void main() {
  test('splits text on whitespace and drops empty tokens', () {
    final words = WordTokenizer.tokenizeText(
      'Ciao   mondo,\nquesto è   un test.',
    );

    expect(words, ['Ciao', 'mondo,', 'questo', 'è', 'un', 'test.']);
  });

  test('tokenizeBytes decodes utf-8 before splitting', () {
    final bytes = Uint8List.fromList(utf8.encode('caffè buono'));

    expect(WordTokenizer.tokenizeBytes(bytes), ['caffè', 'buono']);
  });

  test('falls back to latin-1 when bytes are not valid utf-8', () {
    // 0xE0 is 'à' in Latin-1 but is not a valid standalone UTF-8 byte.
    final bytes = Uint8List.fromList([...'caff'.codeUnits, 0xE0]);

    expect(WordTokenizer.tokenizeBytes(bytes), ['caffà']);
  });
}
