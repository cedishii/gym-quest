import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../config/balance.dart';
import '../../../data/persistence/game_save.dart';
import '../../../domain/combat/battle.dart';
import '../../../domain/combat/element.dart';
import '../../../domain/map/stages.dart';
import '../../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/bars.dart';
import '../../widgets/feedback.dart';
import '../../widgets/game_icon.dart';
import '../../widgets/pet_sprite.dart';

/// Turn-based battle. Rules live in [BattleEngine]; this screen plays the
/// returned events back as animations, then records the result.
class BattleScreen extends StatefulWidget {
  const BattleScreen.stage(int this.stageIndex, {super.key});

  const BattleScreen.endless({super.key}) : stageIndex = null;

  /// Story stage, or null for the Endless Tower.
  final int? stageIndex;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with TickerProviderStateMixin {
  late final BattleEngine _engine;
  late BattleState _state;
  late int _playerHp;
  late int _enemyHp;
  late final Stage? _stage;
  late final int _endlessFloor;

  bool _busy = false;
  bool _done = false;
  String _message = '';

  // Animation state.
  late final AnimationController _playerLunge = _ctrl(320);
  late final AnimationController _enemyLunge = _ctrl(320);
  late final AnimationController _playerShake = _ctrl(380);
  late final AnimationController _enemyShake = _ctrl(380);
  late final AnimationController _fx = _ctrl(520);
  Side? _fxTarget;
  String _fxAsset = 'assets/fx/spark_05.png';
  Color _fxColor = Colors.white;
  final List<_Popup> _popups = [];

  AnimationController _ctrl(int ms) => AnimationController(
    vsync: this,
    duration: Duration(milliseconds: ms),
  );

  @override
  void initState() {
    super.initState();
    final app = context.appRead;
    _engine = BattleEngine(app.random);
    if (widget.stageIndex != null) {
      _stage = GameMap.stages[widget.stageIndex!];
      _endlessFloor = 0;
      _state = app.startStageBattle(widget.stageIndex!);
      _message = _stage!.kind == StageKind.wild
          ? 'A ${_state.enemy.name.toLowerCase()} appears!'
          : '${_stage.opponentName} sends out ${_state.enemy.name}!';
    } else {
      _stage = null;
      _endlessFloor = app.mapProgress.endlessFloor;
      _state = app.startEndlessBattle();
      _message =
          'Endless Tower, floor $_endlessFloor: ${_state.enemy.name} appears!';
    }
    _playerHp = _state.player.hp;
    _enemyHp = _state.enemy.hp;
  }

  @override
  void dispose() {
    for (final c in [
      _playerLunge,
      _enemyLunge,
      _playerShake,
      _enemyShake,
      _fx,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  PetElement get _backdropElement =>
      _stage?.region.element ?? _state.enemy.element;

  Future<void> _act(BattleAction action) async {
    if (_busy || _done) return;
    setState(() => _busy = true);
    final result = _engine.playRound(_state, action);
    for (final event in result.events) {
      if (!mounted) return;
      await _play(event);
    }
    if (!mounted) return;
    setState(() {
      _state = result.state;
      _playerHp = _state.player.hp;
      _enemyHp = _state.enemy.hp;
      _busy = false;
    });
    if (_state.finished) await _finish();
  }

  Future<void> _play(BattleEvent e) async {
    final app = context.appRead;
    final attackerIsPlayer = e.actor == Side.player;
    final attacker = attackerIsPlayer ? _state.player : _state.enemy;
    setState(() => _message = e.text);

    if (e.action == BattleAction.guard) {
      app.sound.play(Sfx.guard);
      _showFx(e.actor, 'assets/fx/circle_05.png', Palette.xp);
      setState(() {
        if (attackerIsPlayer) {
          _playerHp += e.healed;
        } else {
          _enemyHp += e.healed;
        }
        if (e.healed > 0) {
          _popups.add(_Popup(e.actor, '+${e.healed}', Palette.hp));
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return;
    }

    await (attackerIsPlayer ? _playerLunge : _enemyLunge).forward(from: 0);
    (attackerIsPlayer ? _playerLunge : _enemyLunge).reverse();
    final target = attackerIsPlayer ? Side.enemy : Side.player;

    if (e.missed) {
      app.sound.play(Sfx.back);
      setState(() => _popups.add(_Popup(target, 'Miss', Palette.textDim)));
      await Future<void>.delayed(const Duration(milliseconds: 650));
      return;
    }

    final elemental = e.action != BattleAction.strike;
    _showFx(
      target,
      elemental ? _elementFx(attacker.element) : 'assets/fx/slash_03.png',
      elemental ? Palette.element(attacker.element) : Colors.white,
    );
    app.sound.play(switch (e.action) {
      BattleAction.ultimate => Sfx.heavyHit,
      BattleAction.blast =>
        attacker.element == PetElement.rock ? Sfx.rockHit : Sfx.softHit,
      _ => Sfx.hit,
    });
    (target == Side.player ? _playerShake : _enemyShake).forward(from: 0);
    setState(() {
      if (target == Side.player) {
        _playerHp = max(0, _playerHp - e.damage);
      } else {
        _enemyHp = max(0, _enemyHp - e.damage);
      }
      _popups.add(
        _Popup(
          target,
          '-${e.damage}${e.critical ? '!' : ''}',
          e.multiplier > 1
              ? Palette.gold
              : (e.multiplier < 1 ? Palette.textDim : Colors.white),
        ),
      );
    });
    await Future<void>.delayed(
      Duration(milliseconds: e.targetFainted ? 1100 : 800),
    );
  }

  void _showFx(Side target, String asset, Color color) {
    setState(() {
      _fxTarget = target;
      _fxAsset = asset;
      _fxColor = color;
    });
    _fx.forward(from: 0);
  }

  static String _elementFx(PetElement e) => switch (e) {
    PetElement.fire => 'assets/fx/flame_04.png',
    PetElement.water => 'assets/fx/twirl_02.png',
    PetElement.leaf => 'assets/fx/magic_03.png',
    PetElement.rock => 'assets/fx/dirt_02.png',
    PetElement.neutral => 'assets/fx/star_06.png',
  };

  Future<void> _finish() async {
    final app = context.appRead;
    _done = true;
    final won = _state.winner == Side.player;
    app.sound.play(won ? Sfx.victory : Sfx.defeat);
    final BattleOutcome outcome = widget.stageIndex != null
        ? app.finishStageBattle(widget.stageIndex!, _state)
        : app.finishEndlessBattle(_state);
    if (!mounted) return;

    if (won) {
      await showRewardDialog(
        context,
        title: 'Victory!',
        reward: outcome.reward,
        unlocks: outcome.unlocks,
        icon: 'laurels',
        lines: [
          if (_stage?.kind == StageKind.leader && outcome.firstClear)
            'You earned the ${_stage!.region.badgeName}!',
          if (!outcome.firstClear && _stage != null)
            'Practice win (rewards are for the first clear only).',
          if (outcome.unlockedNext != null) outcome.unlockedNext!,
        ],
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Defeated...'),
          content: Text(
            _state.round >= Balance.maxBattleRounds
                ? 'The battle dragged on too long. Try attacking more and guarding less.'
                : 'Your pet needs to get stronger:\n\n'
                      '• Finish workouts to earn food, then feed your pet to level up\n'
                      '• Equip items from your bag\n'
                      '• Use super-effective moves and Guard when HP is low',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to map'),
            ),
          ],
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _flee() async {
    if (_done) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await confirm(
      context,
      title: 'Leave battle?',
      message: 'Nothing is lost, but nothing is won either.',
      confirmLabel: 'Leave',
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  void _toggleSound() {
    final app = context.appRead;
    final s = app.settings;
    final on = !(s.music || s.sfx);
    app.updateSettings(
      Settings(music: on, sfx: on, musicVolume: s.musicVolume),
    );
    if (on) app.sound.startMusic();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final soundOn = app.settings.music || app.settings.sfx;
    final colors = Palette.backdrop(_backdropElement);
    final player = _state.player;
    final enemy = _state.enemy;

    return PopScope(
      canPop: _done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _flee();
      },
      child: Scaffold(
        backgroundColor: colors.last,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            _stage == null
                ? 'Endless · Floor $_endlessFloor'
                : _stage.region.name,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _flee,
          ),
          actions: [
            IconButton(
              tooltip: soundOn ? 'Mute' : 'Sound on',
              onPressed: _toggleSound,
              icon: Icon(
                soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              ),
            ),
          ],
        ),
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.first, colors.last],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth, h = c.maxHeight;
                      final spriteSize = min(w * 0.42, h * 0.42);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Arena floor ellipses.
                          Positioned(
                            right: w * 0.06,
                            top: h * 0.30,
                            child: _platform(spriteSize),
                          ),
                          Positioned(
                            left: w * 0.04,
                            bottom: h * 0.04,
                            child: _platform(spriteSize * 1.1),
                          ),
                          // Enemy.
                          Positioned(
                            right: w * 0.08,
                            top: h * 0.30 - spriteSize * 0.85,
                            child: _fighter(
                              side: Side.enemy,
                              lunge: _enemyLunge,
                              shake: _enemyShake,
                              direction: const Offset(-1, 0.6),
                              child: PetSprite(
                                element: enemy.element,
                                level: enemy.level,
                                size: spriteSize,
                                flip: true,
                                fixedScale: 0.95,
                              ),
                            ),
                          ),
                          // Player.
                          Positioned(
                            left: w * 0.06,
                            bottom: h * 0.04 + spriteSize * 0.08,
                            child: _fighter(
                              side: Side.player,
                              lunge: _playerLunge,
                              shake: _playerShake,
                              direction: const Offset(1, -0.6),
                              child: PetSprite(
                                element: player.element,
                                level: player.level,
                                size: spriteSize * 1.1,
                              ),
                            ),
                          ),
                          // HP cards.
                          Positioned(
                            left: Space.md,
                            top: Space.md,
                            width: min(w * 0.5, 260),
                            child: _HpCard(
                              combatant: enemy,
                              hp: _enemyHp,
                              portrait: _stage?.portrait,
                            ),
                          ),
                          Positioned(
                            right: Space.md,
                            bottom: h * 0.12,
                            width: min(w * 0.5, 260),
                            child: _HpCard(
                              combatant: player,
                              hp: _playerHp,
                              showNumbers: true,
                            ),
                          ),
                          // Hit effect.
                          if (_fxTarget != null)
                            AnimatedBuilder(
                              animation: _fx,
                              builder: (context, _) {
                                if (_fx.value == 0 || _fx.value == 1) {
                                  return const SizedBox.shrink();
                                }
                                final onEnemy = _fxTarget == Side.enemy;
                                final size =
                                    spriteSize * (0.6 + 0.7 * _fx.value);
                                final cx = onEnemy
                                    ? w - w * 0.08 - spriteSize / 2
                                    : w * 0.06 + spriteSize * 0.55;
                                final cy = onEnemy
                                    ? h * 0.30 - spriteSize * 0.4
                                    : h - h * 0.04 - spriteSize * 0.5;
                                return Positioned(
                                  left: cx - size / 2,
                                  top: cy - size / 2,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: (1 - _fx.value).clamp(0.0, 1.0),
                                      child: Transform.rotate(
                                        angle: _fx.value * 1.4,
                                        child: Image.asset(
                                          _fxAsset,
                                          width: size,
                                          height: size,
                                          color: _fxColor,
                                          colorBlendMode: BlendMode.modulate,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          // Damage numbers.
                          for (final p in _popups)
                            _DamagePopup(
                              key: p.key,
                              popup: p,
                              anchor: p.side == Side.enemy
                                  ? Offset(
                                      w - w * 0.08 - spriteSize / 2,
                                      h * 0.30 - spriteSize * 0.9,
                                    )
                                  : Offset(
                                      w * 0.06 + spriteSize * 0.55,
                                      h - h * 0.04 - spriteSize * 1.05,
                                    ),
                              onDone: () => setState(() => _popups.remove(p)),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                // Message box.
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: Space.md),
                  padding: const EdgeInsets.all(Space.md),
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 64),
                  decoration: BoxDecoration(
                    color: Palette.backgroundDeep.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: Palette.border),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _message,
                      key: ValueKey(_message),
                      style: const TextStyle(fontSize: 15, height: 1.3),
                    ),
                  ),
                ),
                const SizedBox(height: Space.sm),
                _ActionPad(
                  state: _state,
                  enabled: !_busy && !_done,
                  onAction: _act,
                ),
                const SizedBox(height: Space.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _platform(double size) => Container(
    width: size,
    height: size * 0.22,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.all(Radius.elliptical(size, size * 0.22)),
      gradient: RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.0),
        ],
      ),
    ),
  );

  Widget _fighter({
    required Side side,
    required AnimationController lunge,
    required AnimationController shake,
    required Offset direction,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([lunge, shake]),
      builder: (context, child) {
        final l = Curves.easeOut.transform(lunge.value) * 28;
        final s = shake.isAnimating
            ? sin(shake.value * pi * 6) * 8 * (1 - shake.value)
            : 0.0;
        final flash = shake.isAnimating && (shake.value * 6).floor().isEven;
        return Transform.translate(
          offset: Offset(direction.dx * l + s, direction.dy * l),
          child: Opacity(opacity: flash ? 0.55 : 1, child: child),
        );
      },
      child: child,
    );
  }
}

class _HpCard extends StatelessWidget {
  const _HpCard({
    required this.combatant,
    required this.hp,
    this.portrait,
    this.showNumbers = false,
  });

  final Combatant combatant;
  final int hp;
  final String? portrait;
  final bool showNumbers;

  @override
  Widget build(BuildContext context) {
    final ratio = combatant.maxHp == 0 ? 0.0 : hp / combatant.maxHp;
    final color = ratio > 0.5
        ? Palette.hp
        : (ratio > 0.2 ? Palette.warning : Palette.danger);
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: Palette.backgroundDeep.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(
          color: Palette.element(combatant.element).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          if (portrait != null) ...[
            ClipOval(
              child: Image.asset(
                portrait!,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.7),
              ),
            ),
            const SizedBox(width: Space.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        combatant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      'Lv ${combatant.level}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Palette.textDim,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GameIcon(
                      elementIcon(combatant.element),
                      size: 12,
                      color: Palette.element(combatant.element),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GameBar(value: ratio, color: color, height: 8),
                    ),
                  ],
                ),
                if (showNumbers)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '$hp / ${combatant.maxHp} HP',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.textDim,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPad extends StatelessWidget {
  const _ActionPad({
    required this.state,
    required this.enabled,
    required this.onAction,
  });

  final BattleState state;
  final bool enabled;
  final ValueChanged<BattleAction> onAction;

  @override
  Widget build(BuildContext context) {
    final me = state.player;
    final blastMult = Matchups.multiplier(me.element, state.enemy.element);
    final color = Palette.element(me.element);
    final charge = (me.charge / Balance.ultimateChargeTurns).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MoveButton(
                  key: const Key('move-blast'),
                  label: me.species.blastName,
                  detail: blastMult > 1
                      ? 'Super effective!'
                      : (blastMult < 1
                            ? 'Not very effective'
                            : 'Power ${Balance.blastPower}'),
                  icon: elementIcon(me.element),
                  color: color,
                  onTap: enabled ? () => onAction(BattleAction.blast) : null,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _MoveButton(
                  key: const Key('move-strike'),
                  label: 'Strike',
                  detail: 'Power ${Balance.strikePower} · never resisted',
                  icon: 'fist',
                  color: Palette.text,
                  onTap: enabled ? () => onAction(BattleAction.strike) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: _MoveButton(
                  key: const Key('move-guard'),
                  label: 'Guard',
                  detail: 'Halve next hit, heal a little',
                  icon: 'shield',
                  color: Palette.xp,
                  onTap: enabled ? () => onAction(BattleAction.guard) : null,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _MoveButton(
                  key: const Key('move-ultimate'),
                  label: me.species.ultimateName,
                  detail: me.ultimateReady
                      ? 'READY · power ${Balance.ultimatePower}'
                      : 'Charging…',
                  icon: 'lightning',
                  color: Palette.gold,
                  progress: charge,
                  onTap: enabled && me.ultimateReady
                      ? () => onAction(BattleAction.ultimate)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({
    super.key,
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
    this.progress,
  });

  final String label;
  final String detail;
  final String icon;
  final Color color;
  final VoidCallback? onTap;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Palette.surface.withValues(alpha: enabled ? 0.95 : 0.6),
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.7) : Palette.border,
            ),
          ),
          child: Row(
            children: [
              GameIcon(
                icon,
                size: 26,
                color: enabled ? color : Palette.textFaint,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: enabled ? Palette.text : Palette.textFaint,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.textDim,
                      ),
                    ),
                    if (progress != null && progress! < 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: GameBar(
                          value: progress!,
                          color: Palette.gold,
                          height: 4,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Popup {
  _Popup(this.side, this.text, this.color);

  final Side side;
  final String text;
  final Color color;
  final Key key = UniqueKey();
}

class _DamagePopup extends StatefulWidget {
  const _DamagePopup({
    super.key,
    required this.popup,
    required this.anchor,
    required this.onDone,
  });

  final _Popup popup;
  final Offset anchor;
  final VoidCallback onDone;

  @override
  State<_DamagePopup> createState() => _DamagePopupState();
}

class _DamagePopupState extends State<_DamagePopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )
        ..forward().whenComplete(() {
          if (mounted) widget.onDone();
        });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => Positioned(
      left: widget.anchor.dx - 40,
      top: widget.anchor.dy - 50 * _c.value,
      width: 80,
      child: IgnorePointer(
        child: Opacity(
          opacity: (1 - _c.value * _c.value).clamp(0.0, 1.0),
          child: Text(
            widget.popup.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.popup.color,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        ),
      ),
    ),
  );
}
