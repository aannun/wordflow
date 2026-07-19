import 'package:flutter_test/flutter_test.dart';
import 'package:wordflow/services/orp.dart';

void main() {
  test('orpIndexFor picks the pivot letter by word length', () {
    expect(orpIndexFor('a'), 0);
    expect(orpIndexFor('to'), 1);
    expect(orpIndexFor('house'), 1);
    expect(orpIndexFor('reading'), 2);
    expect(orpIndexFor('wonderful'), 2);
    expect(orpIndexFor('extraordinary'), 3);
    expect(orpIndexFor('internationalization'), 4);
  });
}
