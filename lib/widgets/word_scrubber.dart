import 'package:flutter/material.dart';

/// Horizontal drag control to manually move through the word list: drag
/// right to step forward, left to step back. Like the speed control,
/// it's delta based rather than mapped to an absolute track position.
class WordScrubber extends StatelessWidget {
  final String progressLabel;
  final ValueChanged<double> onDragDelta;
  final VoidCallback onInteraction;
  final VoidCallback onDragEnd;

  const WordScrubber({
    super.key,
    required this.progressLabel,
    required this.onDragDelta,
    required this.onInteraction,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => onInteraction(),
      onHorizontalDragUpdate: (details) {
        onInteraction();
        onDragDelta(details.delta.dx);
      },
      onHorizontalDragEnd: (_) => onDragEnd(),
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              progressLabel,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.chevron_left, color: Colors.white54),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
