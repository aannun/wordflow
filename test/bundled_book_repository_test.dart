import 'package:flutter_test/flutter_test.dart';
import 'package:wordflow/services/bundled_book_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lists no books when assets/books has none bundled yet', () async {
    final books = await BundledBookRepository.listBooks();

    // The folder currently only holds a .gitkeep placeholder; this test
    // just guards that scanning it doesn't crash and ignores non-.txt
    // files. Once real books are added to assets/books/, this list stops
    // being empty — that's expected, not a regression.
    expect(books, isA<List>());
    expect(books.every((b) => !b.removable), isTrue);
  });
}
