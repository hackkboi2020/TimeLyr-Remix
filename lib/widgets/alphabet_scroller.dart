import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelyr/theme/app_theme.dart';

/// A–Z strip along the edge of a list. Touch or drag on it to jump to a letter.
class AlphabetScroller extends StatefulWidget {
  final ValueChanged<String> onLetter;
  final VoidCallback? onEnd;

  const AlphabetScroller({super.key, required this.onLetter, this.onEnd});

  static const List<String> letters = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  @override
  State<AlphabetScroller> createState() => _AlphabetScrollerState();
}

class _AlphabetScrollerState extends State<AlphabetScroller> {
  String? _active;

  void _handle(double dy, double height) {
    if (height <= 0) return;
    final count = AlphabetScroller.letters.length;
    final index = (dy / height * count).floor().clamp(0, count - 1);
    final letter = AlphabetScroller.letters[index];
    if (letter != _active) {
      setState(() => _active = letter);
      HapticFeedback.selectionClick();
      widget.onLetter(letter);
    }
  }

  void _end() {
    setState(() => _active = null);
    widget.onEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _handle(d.localPosition.dy, height),
          onTapUp: (_) => _end(),
          onTapCancel: _end,
          onVerticalDragStart: (d) => _handle(d.localPosition.dy, height),
          onVerticalDragUpdate: (d) => _handle(d.localPosition.dy, height),
          onVerticalDragEnd: (_) => _end(),
          onVerticalDragCancel: _end,
          child: Container(
            width: 24,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final letter in AlphabetScroller.letters)
                  Text(
                    letter,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: letter == _active
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: letter == _active
                          ? AppTheme.accent
                          : Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
