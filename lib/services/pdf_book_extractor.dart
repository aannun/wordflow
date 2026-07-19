import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Extracts readable text from a PDF and applies light cleanup for the
/// most common artifacts of automated PDF text extraction: bare
/// page-number lines, and words split by a line-break hyphen.
///
/// Works best on simple, single-column PDFs (typical of novels).
/// Multi-column layouts, footnotes, and scanned/image-only PDFs (no
/// embedded text layer) can still produce jumbled or empty output — an
/// inherent limit of automated PDF text extraction, not something this
/// cleanup fully solves.
class PdfBookExtractor {
  static String extractCleanText(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final raw = PdfTextExtractor(document).extractText();
      return cleanExtractedText(raw);
    } finally {
      document.dispose();
    }
  }

  static final _bareNumber = RegExp(r'^[0-9ivxlcIVXLC]+$');
  static final _endsInWordHyphen = RegExp(r'[a-zA-Zà-üÀ-Ü]-$');
  // Only merge across a hyphen when the next line looks like the tail of
  // a word (starts lowercase) — otherwise it's more likely a genuine
  // hyphenated term (e.g. "COVID-19") than a wrapped word, and merging
  // would corrupt it instead of cleaning it up.
  static final _startsLowercase = RegExp(r'^[a-zà-ü]');

  /// Pure text-cleanup step, split out from PDF parsing so it can be unit
  /// tested with plain strings instead of real PDF bytes.
  static String cleanExtractedText(String raw) {
    final lines = <String>[];
    for (final rawLine in raw.split('\n')) {
      final line = rawLine.trim();
      // Drop blank lines and bare page numbers (arabic or roman), a
      // common artifact of extracting a whole page's text as one blob.
      if (line.isEmpty || _bareNumber.hasMatch(line)) continue;
      lines.add(line);
    }

    final buffer = StringBuffer();
    var i = 0;
    while (i < lines.length) {
      var current = lines[i];
      final next = i + 1 < lines.length ? lines[i + 1] : null;

      if (_endsInWordHyphen.hasMatch(current) &&
          next != null &&
          _startsLowercase.hasMatch(next)) {
        current = current.substring(0, current.length - 1) + next;
        i += 2;
      } else {
        i += 1;
      }

      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(current);
    }

    return buffer.toString();
  }
}
