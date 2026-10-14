import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../domain/inventory/items.dart';
import '../../theme/tokens.dart';
import '../../widgets/feedback.dart';
import '../../widgets/game_icon.dart';
import '../../widgets/panel.dart';

/// Items that fit [slot]: equip, swap or unequip.
Future<void> showInventorySheet(BuildContext context, EquipSlot slot) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InventorySheet(slot: slot),
    );

class _InventorySheet extends StatelessWidget {
  const _InventorySheet({required this.slot});

  final EquipSlot slot;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final equippedId = app.equipped[slot];
    final items = app.inventory.where((i) => i.def?.slot == slot).toList()
      ..sort((a, b) => b.def!.rarity.index.compareTo(a.def!.rarity.index));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                0,
                Space.lg,
                Space.sm,
              ),
              child: Row(
                children: [
                  GameIcon(slot.icon, size: 26, color: Palette.gold),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      slot.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (equippedId != null)
                    TextButton(
                      onPressed: () {
                        app.unequip(slot);
                        app.sound.play(Sfx.back);
                      },
                      child: const Text('Unequip'),
                    ),
                ],
              ),
            ),
            if (items.isEmpty)
              const EmptyState(
                icon: GameIcon('backpack', size: 44, color: Palette.textFaint),
                title: 'Nothing for this slot yet',
                message: 'Clear adventure stages, streak milestones and achievements to find equipment.',
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    Space.lg,
                    0,
                    Space.lg,
                    Space.lg,
                  ),
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: _ItemTile(
                          def: item.def!,
                          equipped: item.instanceId == equippedId,
                          onTap: () {
                            if (item.instanceId == equippedId) return;
                            final unlocks = runAction(
                              context,
                              () => app.equip(item.instanceId),
                            );
                            if (unlocks == null) return;
                            app.sound.play(Sfx.equip);
                            if (unlocks.isNotEmpty) {
                              Navigator.of(context).pop();
                              showRewardDialog(
                                context,
                                title: 'Achievement!',
                                reward: unlocks.first.reward,
                                unlocks: unlocks,
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.def,
    required this.equipped,
    required this.onTap,
  });

  final ItemDef def;
  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Palette.rarity(def.rarity);
    return Panel(
      onTap: onTap,
      borderColor: equipped ? Palette.gold : color.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: GameIcon(def.icon, size: 32, color: color),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  def.rarity.label,
                  style: TextStyle(color: color, fontSize: 12),
                ),
                Text(
                  def.effectLabel,
                  style: const TextStyle(color: Palette.hp, fontSize: 12),
                ),
              ],
            ),
          ),
          if (equipped)
            const Text(
              'EQUIPPED',
              style: TextStyle(
                color: Palette.gold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            const Text('Equip', style: TextStyle(color: Palette.textDim)),
        ],
      ),
    );
  }
}
