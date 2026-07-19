import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordflow/services/web_book_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('caches bundled book text per id, separate from uploaded books', () async {
    expect(await WebBookStore.readCachedBundledText('bundled:a.txt'), isNull);

    await WebBookStore.cacheBundledText('bundled:a.txt', 'hello world');

    expect(
      await WebBookStore.readCachedBundledText('bundled:a.txt'),
      'hello world',
    );
    expect(await WebBookStore.readCachedBundledText('bundled:b.txt'), isNull);

    // Caching a bundled book doesn't show up as an uploaded one.
    expect(await WebBookStore.listAll(), isEmpty);
  });
}
