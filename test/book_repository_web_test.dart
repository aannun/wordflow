import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordflow/services/book_repository_web.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add, list, read and delete books stored in the browser', () async {
    expect(await BookRepository.listBooks(), isEmpty);

    await BookRepository.addBook(
      'Zeta',
      utf8.encode('z is last'),
    );
    await BookRepository.addBook(
      'Alpha',
      Uint8List.fromList(utf8.encode('hello world')),
    );

    final books = await BookRepository.listBooks();
    expect(books.map((b) => b.title).toList(), ['Alpha', 'Zeta']);

    final alpha = books.firstWhere((b) => b.title == 'Alpha');
    expect(await alpha.loadWords(), ['hello', 'world']);

    await BookRepository.deleteBook(alpha.id);
    expect(
      (await BookRepository.listBooks()).map((b) => b.title),
      ['Zeta'],
    );
  });
}
