import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordflow/widgets/scrolling_words_view.dart';

void main() {
  const words = ['alpha', 'beta', 'gamma', 'delta'];
  const style = TextStyle(fontSize: 20, color: Colors.white);
  const screenWidth = 300.0;

  List<double> measure() {
    final painter = TextPainter(textDirection: TextDirection.ltr);
    return words.map((w) {
      painter.text = TextSpan(text: '$w ', style: style);
      painter.layout();
      return painter.width;
    }).toList();
  }

  Future<void> pump(WidgetTester tester, Animation<double> progress) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: screenWidth,
            height: 80,
            child: ScrollingWordsView(
              windowWords: words,
              windowStart: 0,
              windowWidths: measure(),
              currentIndex: 1,
              progress: progress,
              style: style,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('centers the current word at the marker when progress is 0', (
    tester,
  ) async {
    await pump(tester, const AlwaysStoppedAnimation(0.0));

    final wordCenter = tester.getCenter(find.text('beta')).dx;

    expect(wordCenter, closeTo(screenWidth / 2, 0.5));
  });

  testWidgets(
    'shows the next word centered at the marker when progress reaches 1',
    (tester) async {
      await pump(tester, const AlwaysStoppedAnimation(1.0));

      final wordCenter = tester.getCenter(find.text('gamma')).dx;

      expect(wordCenter, closeTo(screenWidth / 2, 0.5));
    },
  );

  testWidgets('renders every word with the same plain style, no marker', (
    tester,
  ) async {
    await pump(tester, const AlwaysStoppedAnimation(0.0));

    final betaStyle = tester.widget<Text>(find.text('beta')).style;
    final alphaStyle = tester.widget<Text>(find.text('alpha')).style;

    expect(betaStyle?.color, Colors.white);
    expect(betaStyle?.fontWeight, alphaStyle?.fontWeight);
    // No standalone Container is used for a marker line anymore.
    expect(find.byType(Container), findsNothing);
  });
}
