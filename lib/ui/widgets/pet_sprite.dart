import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/combat/element.dart';
import '../../domain/pet/pet.dart';
import '../../domain/pet/species.dart';
import '../theme/tokens.dart';
import 'game_icon.dart';

/// The pet drawn at its growth size, alive: it breathes, sways, hops now
/// and then, stands on a soft shadow and is surrounded by a faint glow and
/// drifting sparks of its element. Aura tiers add more as it levels:
/// 1 = stronger glow, 2 = swirling aura, 3 = sparkles, 4 = crown.
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
  /// One loop = 6 s: two breaths, one sway, one hop near the end.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6000),
  );

  /// Pets start at different points of the loop so a row of them is not
  /// moving in lockstep.
  late final double _phase = Random().nextDouble();

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
    final sprite = Image.asset(
      Species.of(widget.element).asset,
      width: spriteSize,
      height: spriteSize,
      filterQuality: FilterQuality.medium,
    );

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        child: sprite,
        builder: (context, child) {
          final v = (_controller.value + _phase) % 1;
          final t = v * 2 * pi;
          // Breathing: two breaths per loop, squash and stretch.
          final breath = sin(t * 2);
          final stretchY = 1 + breath * 0.035;
          final stretchX = 1 - breath * 0.025;
          // Gentle sway.
          final sway = sin(t) * 0.035;
          // A quick hop between 82% and 92% of the loop.
          final hopT = ((v - 0.82) / 0.10).clamp(0.0, 1.0);
          final hop = widget.animate ? sin(hopT * pi) * spriteSize * 0.10 : 0.0;
          final glowPulse = 0.5 + 0.5 * sin(t * 2);

          return Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Soft ground shadow: smaller and lighter while hopping.
              Positioned(
                bottom: 0,
                child: Container(
                  width: spriteSize * (0.70 - hop / spriteSize),
                  height: spriteSize * 0.12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: RadialGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.45 - hop / spriteSize),
                        Colors.black.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              // Element glow, always there; brighter with aura tiers.
              if (widget.showAura)
                Positioned(
                  bottom: spriteSize * 0.08,
                  child: Container(
                    width: spriteSize * (1.0 + 0.1 * tier),
                    height: spriteSize * (1.0 + 0.1 * tier),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(
                            alpha: 0.16 + 0.07 * tier + 0.06 * glowPulse,
                          ),
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
                      opacity: 0.5,
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
              // Drifting element sparks (drawn in code).
              if (widget.showAura)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _MotesPainter(
                        progress: v,
                        color: color,
                        count: 5 + tier * 3,
                        spread: spriteSize,
                      ),
                    ),
                  ),
                ),
              // The pet itself.
              Positioned(
                bottom: spriteSize * 0.05 + hop,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..rotateZ(sway)
                    ..scaleByDouble(
                      (widget.flip ? -1.0 : 1.0) * stretchX,
                      stretchY,
                      1,
                      1,
                    ),
                  child: child,
                ),
              ),
              if (tier >= 3)
                for (var i = 0; i < 3; i++)
                  Positioned(
                    bottom:
                        spriteSize * (0.35 + 0.5 * ((i * 0.37 + v * 3) % 1)),
                    left:
                        widget.size / 2 +
                        cos(t * 3 + i * 2.1) * spriteSize * 0.55 -
                        8,
                    child: Opacity(
                      opacity: 1 - ((i * 0.37 + v * 3) % 1),
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
                  bottom: spriteSize * 0.97 + hop,
                  child: const GameIcon('crown', size: 30, color: Palette.gold),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Small glowing dots that rise around the pet and fade out.
class _MotesPainter extends CustomPainter {
  _MotesPainter({
    required this.progress,
    required this.color,
    required this.count,
    required this.spread,
  });

  final double progress;
  final Color color;
  final int count;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(count * 7919);
    final cx = size.width / 2;
    for (var i = 0; i < count; i++) {
      final offset = rng.nextDouble();
      final x = cx + (rng.nextDouble() - 0.5) * spread * 1.1;
      final speed = 1 + rng.nextInt(2);
      final life = (progress * speed + offset) % 1;
      final y = size.height - spread * 0.1 - life * spread * 0.9;
      final alpha = sin(life * pi) * 0.75;
      final radius = 1.5 + rng.nextDouble() * 2.5;
      final drift = sin((life + offset) * 2 * pi) * 6;
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x + drift, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_MotesPainter old) =>
      old.progress != progress || old.color != color || old.count != count;
}
