import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wordflow/services/pdf_book_extractor.dart';

void main() {
  group('cleanExtractedText (pure text cleanup)', () {
    test('rejoins a word hyphenated across a line break', () {
      final result = PdfBookExtractor.cleanExtractedText(
        'The quick brown fox jumps over the beauti-\n'
        'ful lazy dog near the riverbank.',
      );

      expect(
        result,
        'The quick brown fox jumps over the beautiful lazy dog near the '
        'riverbank.',
      );
    });

    test('drops bare page-number lines', () {
      final result = PdfBookExtractor.cleanExtractedText(
        'Chapter one\n42\nContinues here.\nXIV\n',
      );

      expect(result, 'Chapter one Continues here.');
    });

    test('does not merge a real trailing hyphen followed by a digit', () {
      // e.g. "page-1" style content shouldn't be treated as a wrapped word.
      final result = PdfBookExtractor.cleanExtractedText('COVID-\n19 update');

      expect(result, contains('COVID-'));
    });

    test('ignores blank lines', () {
      final result = PdfBookExtractor.cleanExtractedText(
        'First line.\n\n\nSecond line.',
      );

      expect(result, 'First line. Second line.');
    });
  });

  group('extractCleanText (real PDF, via Syncfusion)', () {
    test('extracts and cleans text from a generated sample PDF', () {
      final bytes = File(
        'test/fixtures/sample_book.pdf',
      ).readAsBytesSync();

      final text = PdfBookExtractor.extractCleanText(bytes);

      expect(text, contains('beautiful lazy dog near the riverbank'));
      expect(text, contains('Chapter two starts on this page'));
      // The "1" / "2" page-number footers must not survive as stray
      // tokens in the extracted text.
      expect(RegExp(r'(^|\s)1(\s|$)').hasMatch(text), isFalse);
      expect(RegExp(r'(^|\s)2(\s|$)').hasMatch(text), isFalse);
    });
  });
}
