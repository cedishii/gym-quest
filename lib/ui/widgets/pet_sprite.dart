import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/combat/element.dart';
import '../../domain/pet/pet.dart';
import '../../domain/pet/species.dart';
import '../theme/tokens.dart';
import 'game_icon.dart';

/// The pet drawn at its growth size with an idle bob and its aura tier:
/// 1 = glow, 2 = swirling aura, 3 = sparkles, 4 = crown.
class PetSprite extends StatefulWidget {
  const PetSprite({
    super.key,
    required this.element,
    required this.level,
    this.size = 220,
    this.animate = true,
    this.flip = false,
    this.showAura = true,
    this.fixedScale,
  });

  final PetElement element;
  final int level;

  /// Box size at full growth; younger pets are drawn smaller inside it.
  final double size;
  final bool animate;
  final bool flip;
  final bool showAura;

  /// Overrides the level-based scale (e.g. pet selection cards).
  final double? fixedScale;

  @override
  State<PetSprite> createState() => _PetSpriteState();
}

class _PetSpriteState extends State<PetSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(PetSprite old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_controller.isAnimating) _controller.repeat();
    if (!widget.animate && _controller.isAnimating) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Palette.element(widget.element);
    final scale = widget.fixedScale ?? PetProgression.scale(widget.level);
    final tier = widget.showAura ? PetProgression.auraTier(widget.level) : 0;
    final spriteSize = widget.size * scale;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * pi;
          final bob = sin(t) * 4;
          final squash = 1 + sin(t) * 0.012;
          return Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Ground shadow.
              Positioned(
                bottom: 2,
                child: Container(
                  width: spriteSize * 0.62,
                  height: spriteSize * 0.08,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (tier >= 1)
                Positioned(
                  bottom: spriteSize * 0.12,
                  child: Container(
                    width: spriteSize * 0.95,
                    height: spriteSize * 0.95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: 0.38 + 0.08 * sin(t)),
                          color.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              if (tier >= 2)
                Positioned(
                  bottom: spriteSize * 0.02,
                  child: Transform.rotate(
                    angle: t,
                    child: Opacity(
                      opacity: 0.55,
                      child: Image.asset(
                        'assets/fx/twirl_02.png',
                        width: spriteSize * 1.05,
                        height: spriteSize * 1.05,
                        color: color,
                        colorBlendMode: BlendMode.modulate,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 6 + bob.abs(),
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(
                    widget.flip ? -1.0 : 1.0,
                    squash,
                    1,
                  ),
                  child: Image.asset(
                    Species.of(widget.element).asset,
                    width: spriteSize,
                    height: spriteSize,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              if (tier >= 3)
                for (var i = 0; i < 3; i++)
                  Positioned(
                    bottom:
                        spriteSize *
                        (0.35 + 0.5 * ((i * 0.37 + _controller.value) % 1)),
                    left:
                        widget.size / 2 +
                        cos(t + i * 2.1) * spriteSize * 0.55 -
                        8,
                    child: Opacity(
                      opacity: 1 - ((i * 0.37 + _controller.value) % 1),
                      child: Image.asset(
                        'assets/fx/star_06.png',
                        width: 16,
                        height: 16,
                        color: Palette.gold,
                      ),
                    ),
                  ),
              if (tier >= 4)
                Positioned(
                  bottom: 6 + bob.abs() + spriteSize * 0.9,
                  child: const GameIcon('crown', size: 30, color: Palette.gold),
                ),
            ],
          );
        },
      ),
    );
  }
}
