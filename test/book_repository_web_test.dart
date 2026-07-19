import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordflow/services/book_repository_web.dart';

void main() {
  // BookRepository now also lists bundled assets, which requires the
  // Flutter binding (asset loading) to be initialized even in a plain
  // `test()`, not just `testWidgets()`.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add, list, read and delete .txt books stored in the browser', () async {
    final before = await BookRepository.listBooks();
    expect(before.where((b) => b.removable), isEmpty);

    await BookRepository.addBook('Zeta.txt', utf8.encode('z is last'));
    await BookRepository.addBook(
      'Alpha.txt',
      Uint8List.fromList(utf8.encode('hello world')),
    );

    final books = await BookRepository.listBooks();
    final ownTitles = books
        .where((b) => b.removable)
        .map((b) => b.title)
        .toList();
    expect(ownTitles, ['Alpha', 'Zeta']);

    final alpha = books.firstWhere((b) => b.title == 'Alpha');
    expect(await alpha.loadWords(), ['hello', 'world']);

    await BookRepository.deleteBook(alpha.id);
    final afterDelete = await BookRepository.listBooks();
    expect(
      afterDelete.where((b) => b.removable).map((b) => b.title),
      ['Zeta'],
    );
  });

  test('uploading a .pdf extracts and stores its text', () async {
    final bytes = File('test/fixtures/sample_book.pdf').readAsBytesSync();

    await BookRepository.addBook('Report.pdf', bytes);

    final books = await BookRepository.listBooks();
    final report = books.firstWhere((b) => b.title == 'Report');
    expect(report.removable, isTrue);
    expect(await report.loadWords(), contains('beautiful'));
  });
}
