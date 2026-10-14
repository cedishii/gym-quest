import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../domain/combat/element.dart';
import '../../../domain/map/stages.dart';
import '../../theme/tokens.dart';
import '../../widgets/game_icon.dart';
import '../../widgets/pet_sprite.dart';
import 'battle_screen.dart';
import 'stage_sheet.dart';

/// Candy-Crush-style path: stages from the bottom up, one region per
/// element, the Endless Tower at the top.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _spacing = 132.0;
  static const _headerHeight = 96.0;
  static const _regionHeight =
      _headerHeight + GameMap.stagesPerRegion * _spacing + 24;

  final _scroll = ScrollController();
  bool _scrolled = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToCurrent(int current) {
    if (_scrolled) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final region = current ~/ GameMap.stagesPerRegion;
      final target =
          (region * _regionHeight +
                  (current % GameMap.stagesPerRegion) * _spacing -
                  160)
              .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openStage(Stage stage) {
    context.appRead.sound.play(Sfx.open);
    showStageSheet(context, stage);
  }

  void _openEndless() {
    final app = context.appRead;
    if (!app.mapProgress.endlessUnlocked) {
      app.sound.play(Sfx.error);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beat Arena Champion Aiko to open the Endless Tower.'),
        ),
      );
      return;
    }
    app.sound.play(Sfx.confirm);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BattleScreen.endless()));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final progress = app.mapProgress;
    final current = progress.currentIndex;
    _scrollToCurrent(min(current, GameMap.lastStoryIndex));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adventure'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Space.lg),
            child: Row(
              children: [
                const GameIcon('medal', size: 20, color: Palette.gold),
                const SizedBox(width: 4),
                Text(
                  '${progress.badges}/5',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        controller: _scroll,
        reverse: true,
        padding: EdgeInsets.zero,
        children: [
          for (var r = 0; r < GameMap.regions.length; r++)
            SizedBox(
              height: _regionHeight,
              child: _RegionSection(
                region: GameMap.regions[r],
                regionIndex: r,
                progress: progress,
                spacing: _spacing,
                headerHeight: _headerHeight,
                onTap: _openStage,
              ),
            ),
          _EndlessTower(progress: progress, onTap: _openEndless),
        ],
      ),
    );
  }
}

class _RegionSection extends StatelessWidget {
  const _RegionSection({
    required this.region,
    required this.regionIndex,
    required this.progress,
    required this.spacing,
    required this.headerHeight,
    required this.onTap,
  });

  final Region region;
  final int regionIndex;
  final MapProgress progress;
  final double spacing;
  final double headerHeight;
  final ValueChanged<Stage> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Palette.backdrop(region.element);
    final accent = Palette.element(region.element);
    final stages = GameMap.stages.where((s) => s.region == region).toList();
    final leaderCleared = progress.isCleared(stages.last.index);

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        Offset pos(int i) {
          // Nodes zig-zag up the screen; i = 0 is the bottom node.
          final x = width * (0.5 + 0.26 * sin(i * 1.7 + regionIndex * 0.9));
          final y = c.maxHeight - 70 - i * spacing;
          return Offset(x, y);
        }

        final points = [for (var i = 0; i < stages.length; i++) pos(i)];
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.first, colors.last],
                  ),
                ),
              ),
            ),
            // Decorative element particles in the background.
            for (var i = 0; i < 6; i++)
              Positioned(
                left: (width * ((i * 0.37 + regionIndex * 0.21) % 1)) - 40,
                top:
                    headerHeight +
                    (c.maxHeight - headerHeight) *
                        ((i * 0.53 + regionIndex * 0.13) % 1) -
                    40,
                child: Opacity(
                  opacity: 0.08,
                  child: Image.asset(
                    _decoration(region.element),
                    width: 120,
                    height: 120,
                    color: accent,
                    colorBlendMode: BlendMode.modulate,
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(painter: _PathPainter(points, accent)),
            ),
            Positioned(
              left: Space.lg,
              right: Space.lg,
              top: Space.md,
              child: Row(
                children: [
                  GameIcon(
                    elementIcon(region.element),
                    size: 30,
                    color: accent,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          region.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          region.intro,
                          style: const TextStyle(
                            color: Palette.textDim,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  if (leaderCleared)
                    Tooltip(
                      message: region.badgeName,
                      child: const GameIcon(
                        'medal',
                        size: 30,
                        color: Palette.gold,
                      ),
                    ),
                ],
              ),
            ),
            for (var i = 0; i < stages.length; i++)
              Positioned(
                left: points[i].dx - 48,
                top: points[i].dy - 48,
                child: _StageNode(
                  stage: stages[i],
                  progress: progress,
                  onTap: () => onTap(stages[i]),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _decoration(PetElement e) => switch (e) {
    PetElement.fire => 'assets/fx/flame_04.png',
    PetElement.water => 'assets/fx/circle_03.png',
    PetElement.leaf => 'assets/fx/magic_03.png',
    PetElement.rock => 'assets/fx/dirt_02.png',
    PetElement.neutral => 'assets/fx/star_06.png',
  };
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.points, this.color);

  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, size.height + 10);
    path.lineTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final mid = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, mid, b.dx, mid, b.dx, b.dy);
    }
    path.lineTo(points.last.dx, -10);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawPath(path, paint);
    // Dotted trail on top.
    final dots = Paint()..color = color.withValues(alpha: 0.55);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 18) {
        final t = metric.getTangentForOffset(d);
        if (t != null) canvas.drawCircle(t.position, 3, dots);
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.points != points || old.color != color;
}

class _StageNode extends StatefulWidget {
  const _StageNode({
    required this.stage,
    required this.progress,
    required this.onTap,
  });

  final Stage stage;
  final MapProgress progress;
  final VoidCallback onTap;

  @override
  State<_StageNode> createState() => _StageNodeState();
}

class _StageNodeState extends State<_StageNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stage;
    final cleared = widget.progress.isCleared(s.index);
    final unlocked = widget.progress.isUnlocked(s.index);
    final current = unlocked && !cleared;
    final leader = s.kind == StageKind.leader;
    final size = leader ? 84.0 : 68.0;
    final color = Palette.element(s.element);

    Widget face;
    if (!unlocked) {
      face = const Icon(Icons.lock_rounded, color: Palette.textFaint, size: 28);
    } else if (s.portrait != null) {
      face = ClipOval(
        child: Image.asset(
          s.portrait!,
          width: size - 8,
          height: size - 8,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.6),
        ),
      );
    } else {
      face = PetSprite(
        element: s.element,
        level: 1,
        size: size - 10,
        fixedScale: 0.9,
        animate: false,
        showAura: false,
      );
    }

    return SizedBox(
      width: 96,
      height: 96 + 22,
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Center(
              child: Semantics(
                button: true,
                label:
                    'Stage ${s.index + 1}: ${s.opponentName}, level ${s.level}'
                    '${cleared
                        ? ', cleared'
                        : unlocked
                        ? ''
                        : ', locked'}',
                child: GestureDetector(
                  key: Key('stage-${s.index}'),
                  onTap: widget.onTap,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) => Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: unlocked
                            ? Palette.surface
                            : Palette.backgroundDeep,
                        border: Border.all(
                          color: cleared
                              ? Palette.gold
                              : (current ? color : Palette.border),
                          width: current ? 3 + _pulse.value * 2 : 3,
                        ),
                        boxShadow: current
                            ? [
                                BoxShadow(
                                  color: color.withValues(
                                    alpha: 0.35 + 0.3 * _pulse.value,
                                  ),
                                  blurRadius: 18 + 10 * _pulse.value,
                                ),
                              ]
                            : null,
                      ),
                      child: child,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        face,
                        if (cleared)
                          const Positioned(
                            right: -4,
                            bottom: -4,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Palette.gold,
                              child: Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Color(0xFF231A05),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: Palette.backgroundDeep.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              leader ? 'Leader · Lv ${s.level}' : 'Lv ${s.level}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: leader ? FontWeight.w600 : FontWeight.w400,
                color: unlocked ? Palette.text : Palette.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndlessTower extends StatelessWidget {
  const _EndlessTower({required this.progress, required this.onTap});

  final MapProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final open = progress.endlessUnlocked;
    return Container(
      height: 230,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0B16), Color(0xFF2B2550)],
        ),
      ),
      child: Center(
        child: GestureDetector(
          key: const Key('endless'),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(
                'stone-tower',
                size: 84,
                color: open ? Palette.gold : Palette.textFaint,
              ),
              const SizedBox(height: Space.sm),
              Text(
                'Endless Tower',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: open ? Palette.text : Palette.textFaint),
              ),
              Text(
                open
                    ? 'Floor ${progress.endlessFloor} · best ${progress.bestEndlessFloor}'
                    : 'Opens after the Arena Champion',
                style: const TextStyle(color: Palette.textDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
