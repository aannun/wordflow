import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Renders a window of words as a continuously scrolling horizontal
/// strip, with the word at [currentIndex] passing through a fixed marker
/// at the horizontal center as [progress] advances from 0 to 1 (i.e. the
/// interpolation from [currentIndex] toward the next word within the
/// current reading tick).
///
/// Only the small [windowWords] slice (starting at [windowStart]) needs
/// pre-measured widths ([windowWidths], each including its trailing
/// space) — the caller recomputes this window whenever [currentIndex]
/// changes, not every frame, so this widget's own rebuilds (driven by
/// [progress]) stay cheap: just arithmetic, no text measurement.
class ScrollingWordsView extends StatelessWidget {
  final List<String> windowWords;
  final int windowStart;
  final List<double> windowWidths;
  final int currentIndex;
  final Animation<double> progress;
  final TextStyle style;

  const ScrollingWordsView({
    super.key,
    required this.windowWords,
    required this.windowStart,
    required this.windowWidths,
    required this.currentIndex,
    required this.progress,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (windowWidths.isEmpty) return const SizedBox.shrink();

    final cumulative = <double>[0];
    for (final w in windowWidths) {
      cumulative.add(cumulative.last + w);
    }

    double centerOf(int globalIndex) {
      final local = (globalIndex - windowStart).clamp(
        0,
        windowWidths.length - 1,
      );
      return cumulative[local] + windowWidths[local] / 2;
    }

    final currentCenter = centerOf(currentIndex);
    final hasNext = currentIndex + 1 < windowStart + windowWidths.length;
    final nextCenter = hasNext ? centerOf(currentIndex + 1) : currentCenter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final markerX = constraints.maxWidth / 2;

        return ClipRect(
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              final readPos =
                  lerpDouble(currentCenter, nextCenter, progress.value)!;

              final children = <Widget>[];
              for (var i = 0; i < windowWidths.length; i++) {
                final leftEdge = markerX + (cumulative[i] - readPos);
                if (leftEdge + windowWidths[i] < -100 ||
                    leftEdge > constraints.maxWidth + 100) {
                  continue;
                }
                children.add(
                  Positioned(
                    left: leftEdge,
                    top: 0,
                    bottom: 0,
                    width: windowWidths[i],
                    child: Center(
                      child: Text(windowWords[i], style: style),
                    ),
                  ),
                );
              }

              return Stack(children: children);
            },
          ),
        );
      },
    );
  }
}
