import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:wordflow/services/book_repository_io.dart';

/// Fakes the native path_provider channel, which isn't available under
/// `flutter test`, by pointing every lookup at a temp folder.
class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;

  _FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getExternalStoragePath({StorageDirectory? type}) async =>
      path;
}

void main() {
  test('creates the books folder and lists only .txt files by title', () async {
    final base = Directory.systemTemp.createTempSync('wordflow_repo_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(base.path);

    final dir = await BookRepository.getBooksDirectory();
    expect(dir.existsSync(), isTrue);

    File('${dir.path}/Zeta.txt').writeAsStringSync('z');
    File('${dir.path}/alpha.TXT').writeAsStringSync('hello world');
    File('${dir.path}/notes.md').writeAsStringSync('not a book');

    final books = await BookRepository.listBooks();

    expect(books.map((b) => b.title).toList(), ['alpha', 'Zeta']);

    final alpha = books.firstWhere((b) => b.title == 'alpha');
    expect(await alpha.loadWords(), ['hello', 'world']);
  });
}
