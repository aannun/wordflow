import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordflow/services/reading_progress.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to zero, then remembers and clears the saved index', () async {
    expect(await ReadingProgressStore.load('/books/a.txt'), 0);

    await ReadingProgressStore.save('/books/a.txt', 42);
    expect(await ReadingProgressStore.load('/books/a.txt'), 42);

    // A different book keeps its own progress.
    expect(await ReadingProgressStore.load('/books/b.txt'), 0);

    await ReadingProgressStore.clear('/books/a.txt');
    expect(await ReadingProgressStore.load('/books/a.txt'), 0);
  });
}
