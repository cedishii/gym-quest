import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../config/balance.dart';
import '../../../domain/inventory/items.dart';
import '../../../domain/pet/pet_food.dart';
import '../../../domain/rewards/reward.dart';
import '../../theme/tokens.dart';
import '../../widgets/bars.dart';
import '../../widgets/feedback.dart';
import '../../widgets/game_icon.dart';
import '../../widgets/panel.dart';
import '../../widgets/pet_sprite.dart';
import 'inventory_sheet.dart';

class PetScreen extends StatefulWidget {
  const PetScreen({super.key});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> with TickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _levelUp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  int _lastGain = 0;

  @override
  void dispose() {
    _hop.dispose();
    _levelUp.dispose();
    super.dispose();
  }

  Future<void> _feed(PetFood food, int count) async {
    final app = context.appRead;
    final outcome = runAction(context, () => app.feed(food, count: count));
    if (outcome == null) return;
    app.sound.play(Sfx.feed);
    setState(() => _lastGain = food.xp * count);
    _hop.forward(from: 0);
    if (outcome.result.levelsGained > 0) {
      app.sound.play(Sfx.levelUp);
      _levelUp.forward(from: 0);
    }
    final lines = <String>[
      if (outcome.result.levelsGained > 0)
        '${outcome.result.pet.name} reached level ${outcome.result.pet.level}!',
      for (final tier in outcome.result.newAuraTiers) _auraText(tier),
    ];
    if (outcome.result.newAuraTiers.isNotEmpty || outcome.unlocks.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      await showRewardDialog(
        context,
        title: outcome.result.newAuraTiers.isNotEmpty
            ? 'Your pet evolved its aura!'
            : 'Achievement!',
        reward: Reward.none,
        unlocks: outcome.unlocks,
        lines: lines,
        icon: 'lightning',
      );
    }
  }

  static String _auraText(int tier) => switch (tier) {
    1 => 'New look: a warm glow surrounds your pet.',
    2 => 'New look: an elemental aura swirls around your pet.',
    3 => 'New look: sparkles of power!',
    _ => 'New look: a champion\'s crown!',
  };

  Future<void> _rename() async {
    final app = context.appRead;
    final controller = TextEditingController(text: app.pet!.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename pet'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && mounted) runAction(context, () => app.renamePet(name));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pet = app.pet!;
    final stats = app.petStats!;
    final base = app.petBaseStats!;
    final color = Palette.element(pet.element);
    final tier = _tierLabel(pet.level);

    return Scaffold(
      appBar: AppBar(title: const Text('Your pet')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
        children: [
          Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              gradient: RadialGradient(
                center: const Alignment(0, 0.3),
                radius: 0.9,
                colors: [
                  color.withValues(alpha: 0.28),
                  Palette.backdrop(pet.element).last,
                ],
              ),
              border: Border.all(color: Palette.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 18,
                  child: AnimatedBuilder(
                    animation: _hop,
                    builder: (context, child) {
                      final t = Curves.easeOut.transform(_hop.value);
                      final y = _hop.isAnimating
                          ? -28 * (1 - (2 * t - 1) * (2 * t - 1))
                          : 0.0;
                      return Transform.translate(
                        offset: Offset(0, y),
                        child: child,
                      );
                    },
                    child: PetSprite(
                      element: pet.element,
                      level: pet.level,
                      size: 240,
                    ),
                  ),
                ),
                if (_hop.isAnimating || _hop.value > 0)
                  AnimatedBuilder(
                    animation: _hop,
                    builder: (context, _) => Positioned(
                      top: 70 - 40 * _hop.value,
                      child: Opacity(
                        opacity: (1 - _hop.value).clamp(0.0, 1.0),
                        child: Text(
                          '+$_lastGain XP',
                          style: const TextStyle(
                            color: Palette.xp,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedBuilder(
                  animation: _levelUp,
                  builder: (context, _) {
                    if (_levelUp.value == 0 || _levelUp.value == 1) {
                      return const SizedBox.shrink();
                    }
                    final v = _levelUp.value;
                    return Positioned(
                      top: 24,
                      child: Opacity(
                        opacity: v < 0.8 ? 1 : (1 - v) * 5,
                        child: Transform.scale(
                          scale:
                              0.6 +
                              0.6 *
                                  Curves.elasticOut.transform(
                                    (v * 2).clamp(0.0, 1.0),
                                  ),
                          child: const Text(
                            'LEVEL UP!',
                            style: TextStyle(
                              color: Palette.gold,
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(top: 12, left: 12, child: ElementBadge(pet.element)),
                if (tier != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Text(
                      tier,
                      style: const TextStyle(
                        color: Palette.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _rename,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          pet.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: Palette.textDim,
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'Lv ${pet.level}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Palette.gold,
                ),
              ),
            ],
          ),
          Text(
            pet.species.name,
            style: const TextStyle(color: Palette.textDim),
          ),
          const SizedBox(height: Space.sm),
          GameBar(
            value: pet.isMaxLevel ? 1 : pet.xp / pet.xpToNext,
            color: Palette.xp,
            height: 12,
          ),
          const SizedBox(height: 4),
          Text(
            pet.isMaxLevel
                ? 'Max level'
                : '${pet.xp} / ${pet.xpToNext} XP to level ${pet.level + 1}',
            style: const TextStyle(color: Palette.textDim, fontSize: 12),
          ),
          const SectionHeader('Feed'),
          Row(
            children: [
              for (final f in PetFood.values) ...[
                Expanded(
                  child: _FoodCard(
                    food: f,
                    count: app.foodCount(f),
                    onFeed: (n) => _feed(f, n),
                  ),
                ),
                if (f != PetFood.values.last) const SizedBox(width: Space.sm),
              ],
            ],
          ),
          const SectionHeader('Equipment'),
          Row(
            children: [
              for (final slot in EquipSlot.values) ...[
                Expanded(child: _SlotButton(slot: slot)),
                if (slot != EquipSlot.values.last)
                  const SizedBox(width: Space.sm),
              ],
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            '${app.inventory.length} item${app.inventory.length == 1 ? '' : 's'} in your bag · win battles to find more',
            style: const TextStyle(color: Palette.textFaint, fontSize: 12),
          ),
          const SectionHeader('Battle stats'),
          Panel(
            child: Column(
              children: [
                _statRow('HP', base.hp, stats.hp, Palette.hp),
                _statRow('Attack', base.attack, stats.attack, Palette.danger),
                _statRow('Defense', base.defense, stats.defense, Palette.xp),
                _statRow('Speed', base.speed, stats.speed, Palette.gold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _tierLabel(int level) {
    final next = Balance.auraTierLevels.where((l) => l > level).firstOrNull;
    return next == null ? 'MAX AURA' : 'Next look at Lv $next';
  }

  Widget _statRow(String label, double base, double total, Color color) {
    final bonus = total - base;
    final max = _statMax(label);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: Palette.textDim)),
          ),
          Expanded(
            child: GameBar(value: total / max, color: color, height: 8),
          ),
          const SizedBox(width: Space.sm),
          SizedBox(
            width: 82,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${total.round()}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (bonus.round() != 0)
                    TextSpan(
                      text: '  +${bonus.round()}',
                      style: const TextStyle(color: Palette.hp, fontSize: 12),
                    ),
                ],
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  static double _statMax(String label) => switch (label) {
    'HP' => 900,
    'Speed' => 120,
    _ => 180,
  };
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({
    required this.food,
    required this.count,
    required this.onFeed,
  });

  final PetFood food;
  final int count;
  final ValueChanged<int> onFeed;

  @override
  Widget build(BuildContext context) {
    final enabled = count > 0;
    return Panel(
      key: Key('feed-${food.name}'),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.md,
      ),
      onTap: enabled
          ? () => onFeed(1)
          : () => showMessage(
              context,
              '${food.label}: ${food.howToEarn.toLowerCase()}.',
            ),
      borderColor: enabled
          ? Palette.gold.withValues(alpha: 0.5)
          : Palette.border,
      child: Column(
        children: [
          GameIcon(
            food.icon,
            size: 34,
            color: enabled ? Palette.gold : Palette.textFaint,
          ),
          const SizedBox(height: 4),
          Text(
            '× $count',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: enabled ? Palette.text : Palette.textFaint,
            ),
          ),
          Text(
            food.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Palette.textDim),
          ),
          Text(
            '+${food.xp} XP',
            style: const TextStyle(fontSize: 11, color: Palette.xp),
          ),
          if (count >= 5)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
              ),
              onPressed: () => onFeed(count),
              child: const Text('Feed all', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({required this.slot});

  final EquipSlot slot;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final owned = app.equippedIn(slot);
    final def = owned?.def;
    final color = def == null ? Palette.textFaint : Palette.rarity(def.rarity);
    return Panel(
      key: Key('slot-${slot.name}'),
      padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: 4),
      borderColor: def == null ? Palette.border : color.withValues(alpha: 0.7),
      color: def == null ? Palette.surface : color.withValues(alpha: 0.08),
      onTap: () {
        app.sound.play(Sfx.open);
        showInventorySheet(context, slot);
      },
      child: Column(
        children: [
          GameIcon(def?.icon ?? slot.icon, size: 30, color: color),
          const SizedBox(height: 4),
          Text(
            def?.name ?? slot.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: def == null ? Palette.textFaint : Palette.text,
            ),
          ),
        ],
      ),
    );
  }
}
