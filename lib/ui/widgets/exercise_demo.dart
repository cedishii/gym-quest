import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/workout/exercise.dart';
import '../theme/tokens.dart';
import 'game_icon.dart';

/// Shows an exercise's start/end photos, cross-fading between them so the
/// movement reads like a short demo.
class ExerciseDemo extends StatefulWidget {
  const ExerciseDemo({
    super.key,
    required this.exercise,
    this.height = 200,
    this.animate = true,
  });

  final Exercise exercise;
  final double height;
  final bool animate;

  @override
  State<ExerciseDemo> createState() => _ExerciseDemoState();
}

class _ExerciseDemoState extends State<ExerciseDemo> {
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    if (widget.animate && widget.exercise.images.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
        if (mounted) {
          setState(() => _frame = (_frame + 1) % widget.exercise.images.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.exercise.images;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Container(
        height: widget.height,
        width: double.infinity,
        color: Colors.white,
        child: images.isEmpty
            ? const Center(
                child: GameIcon(
                  'weight-lifting',
                  size: 56,
                  color: Palette.textFaint,
                ),
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Image.asset(
                  images[_frame],
                  key: ValueKey(_frame),
                  fit: BoxFit.contain,
                  height: widget.height,
                  errorBuilder: (context, error, stack) => const Center(
                    child: GameIcon(
                      'weight-lifting',
                      size: 56,
                      color: Palette.textFaint,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
