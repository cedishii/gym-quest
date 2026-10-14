import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Rounded progress bar that animates between values.
class GameBar extends StatelessWidget {
  const GameBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 10,
    this.background = Palette.surfaceHigh,
  });

  /// 0..1 (values outside are clamped).
  final double value;
  final Color color;
  final double height;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: background),
            TweenAnimationBuilder<double>(
              tween: Tween(end: v),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => FractionallySizedBox(
                widthFactor: t,
                heightFactor: 1,
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, Color.lerp(color, Colors.white, 0.25)!],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label, value text and a bar underneath (macros, HP, XP...).
class LabeledBar extends StatelessWidget {
  const LabeledBar({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    required this.color,
  });

  final String label;
  final String valueText;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Palette.textDim, fontSize: 13),
            ),
          ),
          Text(
            valueText,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      const SizedBox(height: 6),
      GameBar(value: value, color: color, height: 8),
    ],
  );
}

/// Circular calorie ring.
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.eaten,
    required this.target,
    this.size = 132,
  });

  final double eaten;
  final int target;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ratio = target <= 0 ? 0.0 : eaten / target;
    final over = ratio > 1.05;
    final left = target - eaten.round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: ratio.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: t,
                strokeWidth: 11,
                strokeCap: StrokeCap.round,
                backgroundColor: Palette.surfaceHigh,
                color: over ? Palette.warning : Palette.gold,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${left.abs()}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              Text(
                left >= 0 ? 'kcal left' : 'kcal over',
                style: const TextStyle(fontSize: 12, color: Palette.textDim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
