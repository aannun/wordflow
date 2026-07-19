import 'package:flutter/material.dart';

import '../services/orp.dart';

const _baseFontSize = 48.0;
// Below this scale a very long "word" would become unreadably tiny; better
// to just let it clip than shrink further.
const _minOrpScale = 0.18;

/// Displays a single word.
///
/// Two display modes:
/// - [orpFixed] = false: the word is centered on screen as plain text.
///   There's no fixed anchor point to highlight a letter against, so it
///   isn't highlighted here.
/// - [orpFixed] = true: the word's ORP letter is highlighted and pinned to
///   the horizontal center of the available space, with the rest of the
///   word extending left and right of it. If a long word doesn't fit, the
///   whole word shrinks uniformly so the pivot letter never has to move.
class OrpWord extends StatelessWidget {
  final String word;
  final bool orpFixed;

  const OrpWord({super.key, required this.word, this.orpFixed = false});

  @override
  Widget build(BuildContext context) {
    if (word.isEmpty) return const SizedBox.shrink();

    const baseStyle = TextStyle(
      fontSize: _baseFontSize,
      fontWeight: FontWeight.w400,
      color: Colors.white,
    );

    if (!orpFixed) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(word, style: baseStyle, textAlign: TextAlign.center),
      );
    }

    final pivot = orpIndexFor(word).clamp(0, word.length - 1);
    final before = word.substring(0, pivot);
    final pivotLetter = word[pivot];
    final after = word.substring(pivot + 1);
    final pivotStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.secondary,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = constraints.maxWidth / 2;
        final pivotWidth = _measureWidth(pivotLetter, pivotStyle);
        final budget = (halfWidth - pivotWidth / 2).clamp(1.0, halfWidth);

        final widestSide = [
          _measureWidth(before, baseStyle),
          _measureWidth(after, baseStyle),
        ].reduce((a, b) => a > b ? a : b);

        final scale = widestSide > budget
            ? (budget / widestSide).clamp(_minOrpScale, 1.0)
            : 1.0;

        final scaledBase = baseStyle.copyWith(
          fontSize: _baseFontSize * scale,
        );
        final scaledPivot = pivotStyle.copyWith(
          fontSize: _baseFontSize * scale,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                before,
                textAlign: TextAlign.right,
                style: scaledBase,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
              ),
            ),
            Text(pivotLetter, style: scaledPivot),
            Expanded(
              child: Text(
                after,
                textAlign: TextAlign.left,
                style: scaledBase,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
              ),
            ),
          ],
        );
      },
    );
  }

  double _measureWidth(String text, TextStyle style) {
    if (text.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }
}
