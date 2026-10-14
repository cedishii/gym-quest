import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/combat/battle.dart';
import '../../domain/combat/element.dart';
import '../theme/tokens.dart';

/// How big a hit looks.
enum ImpactKind { strike, blast, ultimate }

ImpactKind impactKindFor(BattleAction action) => switch (action) {
  BattleAction.ultimate => ImpactKind.ultimate,
  BattleAction.blast => ImpactKind.blast,
  _ => ImpactKind.strike,
};

/// Frames of the CC0 Sinestesia explosion animations (see
/// tool/build_effects.dart).
const _animFrames = 32;
String _frame(String anim, int i) =>
    'assets/fx/anim/$anim/${i.toString().padLeft(2, '0')}.png';

/// Loads every effect image ahead of time so the first hit doesn't flicker.
Future<void> precacheBattleEffects(BuildContext context) async {
  final paths = [
    for (var i = 0; i < _animFrames; i++) _frame('blast', i),
    for (var i = 0; i < _animFrames; i++) _frame('nova', i),
    for (var i = 0; i < 6; i++) 'assets/fx/burst/explosion_$i.png',
    for (var i = 0; i < 4; i++) 'assets/fx/burst/flash_$i.png',
    for (var i = 0; i < 8; i++) 'assets/fx/burst/puff_$i.png',
  ];
  await Future.wait([
    for (final p in paths)
      precacheImage(AssetImage(p), context).catchError((Object _) {}),
  ]);
}

/// A one-shot hit effect centred in its box: a burst of smoke/fire
/// particles (Kenney textures tinted per element), code-drawn sparks and a
/// shockwave ring, and for ultimates a frame-by-frame explosion.
class ImpactEffect extends StatefulWidget {
  const ImpactEffect({
    super.key,
    required this.element,
    required this.kind,
    required this.size,
    this.onDone,
  });

  final PetElement element;
  final ImpactKind kind;
  final double size;
  final VoidCallback? onDone;

  @override
  State<ImpactEffect> createState() => _ImpactEffectState();
}

class _Particle {
  _Particle(Random r, int textures)
    : angle = r.nextDouble() * 2 * pi,
      distance = 0.06 + r.nextDouble() * 0.22,
      size = 0.28 + r.nextDouble() * 0.28,
      spin = (r.nextDouble() - 0.5) * 2,
      delay = r.nextDouble() * 0.2,
      texture = r.nextInt(textures);

  final double angle;
  final double distance;
  final double size;
  final double spin;
  final double delay;
  final int texture;
}

class _ImpactEffectState extends State<ImpactEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: switch (widget.kind) {
        ImpactKind.strike => 450,
        ImpactKind.blast => 750,
        ImpactKind.ultimate => 1150,
      },
    ),
  )..forward().whenComplete(() => widget.onDone?.call());

  late final Random _rng = Random();
  late final List<_Particle> _particles = List.generate(switch (widget.kind) {
    ImpactKind.strike => 4,
    ImpactKind.blast => 9,
    ImpactKind.ultimate => 16,
  }, (_) => _Particle(_rng, _textureCount));

  bool get _fiery => widget.element == PetElement.fire;

  int get _textureCount => switch (widget.kind) {
    ImpactKind.strike => 4,
    _ when _fiery => 6,
    _ when widget.element == PetElement.neutral => 4,
    _ => 8,
  };

  String _texture(int i) => switch (widget.kind) {
    ImpactKind.strike => 'assets/fx/burst/flash_$i.png',
    _ when _fiery => 'assets/fx/burst/explosion_$i.png',
    _ when widget.element == PetElement.neutral =>
      'assets/fx/burst/flash_$i.png',
    _ => 'assets/fx/burst/puff_$i.png',
  };

  /// Particle tint: the textures are white/yellow, so modulating gives the
  /// element colour; fire and strikes keep their own colours.
  Color? get _tint => widget.kind == ImpactKind.strike || _fiery
      ? null
      : Color.lerp(Palette.element(widget.element), Colors.white, 0.25);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final color = Palette.element(widget.element);
    return IgnorePointer(
      child: SizedBox(
        width: s,
        height: s,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Shockwave ring and sparks.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SparkPainter(
                      t: t,
                      color: widget.kind == ImpactKind.strike
                          ? Colors.white
                          : color,
                      sparks: switch (widget.kind) {
                        ImpactKind.strike => 8,
                        ImpactKind.blast => 14,
                        ImpactKind.ultimate => 24,
                      },
                      seed: _particles.length,
                    ),
                  ),
                ),
                // Frame-by-frame explosion for ultimates.
                if (widget.kind == ImpactKind.ultimate)
                  Image.asset(
                    _frame(
                      _fiery || widget.element == PetElement.rock
                          ? 'blast'
                          : 'nova',
                      (t * (_animFrames - 1)).floor(),
                    ),
                    width: s * 1.25,
                    height: s * 1.25,
                    gaplessPlayback: true,
                    color: _fiery || widget.element == PetElement.rock
                        ? null
                        : Color.lerp(color, Colors.white, 0.45),
                    colorBlendMode: BlendMode.modulate,
                  ),
                // Particle burst.
                for (final p in _particles) _particle(p, t, s),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _particle(_Particle p, double t, double s) {
    final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
    if (local <= 0) return const SizedBox.shrink();
    final ease = Curves.easeOutCubic.transform(local);
    final dist = p.distance * s * ease;
    final size = s * p.size * (0.4 + 0.8 * ease);
    final fade = 1 - local;
    final opacity = fade * fade * (local < 0.15 ? local / 0.15 : 1);
    return Transform.translate(
      offset: Offset(cos(p.angle) * dist, sin(p.angle) * dist),
      child: Transform.rotate(
        angle: p.spin * local,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Image.asset(
            _texture(p.texture),
            width: size,
            height: size,
            color: _tint,
            colorBlendMode: BlendMode.modulate,
          ),
        ),
      ),
    );
  }
}

/// Code-drawn impact: an expanding shockwave ring and streaks flying out.
class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.t,
    required this.color,
    required this.sparks,
    required this.seed,
  });

  final double t;
  final Color color;
  final int sparks;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Shockwave.
    final ringT = Curves.easeOut.transform((t * 1.6).clamp(0.0, 1.0));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * (1 - ringT) + 1
      ..color = Color.lerp(
        color,
        Colors.white,
        0.5,
      )!.withValues(alpha: (1 - ringT) * 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(c, r * (0.2 + 0.85 * ringT), ring);

    // Core flash.
    final flashT = (t * 3).clamp(0.0, 1.0);
    final flash = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: (1 - flashT) * 0.9),
          color.withValues(alpha: (1 - flashT) * 0.5),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 0.6));
    canvas.drawCircle(c, r * 0.6, flash);

    // Streaks.
    final rng = Random(seed * 31 + sparks);
    final streakT = Curves.easeOutQuart.transform((t * 1.3).clamp(0.0, 1.0));
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        color,
        Colors.white,
        0.6,
      )!.withValues(alpha: (1 - streakT));
    for (var i = 0; i < sparks; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final reach = r * (0.5 + rng.nextDouble() * 0.6);
      final start = reach * streakT * 0.55;
      final end = reach * streakT;
      paint.strokeWidth = 1.5 + rng.nextDouble() * 2.5;
      final dir = Offset(cos(angle), sin(angle));
      canvas.drawLine(c + dir * start, c + dir * end, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t;
}
