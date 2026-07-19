import 'package:flutter/material.dart';

/// Vertical drag control for reading speed: drag up to go faster, drag
/// down to go slower. There's no fixed track range mapped to the drag
/// position — every pixel dragged nudges the speed by a fixed amount, so
/// the reachable range isn't bounded by the widget's height.
class VerticalSpeedControl extends StatelessWidget {
  final int wpm;
  final ValueChanged<double> onDragDelta;
  final VoidCallback onInteraction;
  final VoidCallback onDragEnd;

  const VerticalSpeedControl({
    super.key,
    required this.wpm,
    required this.onDragDelta,
    required this.onInteraction,
    required this.onDragEnd,
  });

  // Only used to place the indicator dot along the track for visual
  // feedback; it doesn't limit how fast or slow wpm can actually go.
  static const _visualMin = 60;
  static const _visualMax = 1200;

  @override
  Widget build(BuildContext context) {
    final t = ((wpm - _visualMin) / (_visualMax - _visualMin)).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => onInteraction(),
      onVerticalDragUpdate: (details) {
        onInteraction();
        onDragDelta(details.delta.dy);
      },
      onVerticalDragEnd: (_) => onDragEnd(),
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            const Icon(Icons.keyboard_arrow_up, color: Colors.white70),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const dotSize = 16.0;
                  final trackHeight = constraints.maxHeight - dotSize;
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Positioned(
                        bottom: t * trackHeight,
                        child: Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
            const SizedBox(height: 8),
            Text(
              '$wpm',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'wpm',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
