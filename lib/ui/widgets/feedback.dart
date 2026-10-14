import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../audio/sound_service.dart';
import '../../data/nutrition/open_food_facts_client.dart';
import '../../domain/inventory/items.dart';
import '../../domain/pet/pet_food.dart';
import '../../domain/rewards/reward.dart';
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import 'game_icon.dart';

void showMessage(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(milliseconds: error ? 3500 : 2000),
        backgroundColor: error ? const Color(0xFF4A1C26) : Palette.surfaceHigh,
      ),
    );
}

/// Runs a state action; shows user-facing errors as a snackbar with a sound.
/// Returns the action's result, or null when it failed.
T? runAction<T>(BuildContext context, T Function() action) {
  try {
    return action();
  } on GameActionException catch (e) {
    context.appRead.sound.play(Sfx.error);
    showMessage(context, e.message, error: true);
  } on FoodLookupException catch (e) {
    context.appRead.sound.play(Sfx.error);
    showMessage(context, e.message, error: true);
  }
  return null;
}

/// Compact list of what a reward contains.
class RewardList extends StatelessWidget {
  const RewardList(this.reward, {super.key});

  final Reward reward;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final food in PetFood.values) {
      final n = reward.count(food);
      if (n <= 0) continue;
      rows.add(
        _row(
          GameIcon(food.icon, size: 22, color: Palette.gold),
          '${food.label} × $n',
        ),
      );
    }
    for (final id in reward.items) {
      final item = ItemCatalog.byId(id);
      if (item == null) continue;
      final color = Palette.rarity(item.rarity);
      rows.add(
        _row(
          GameIcon(item.icon, size: 22, color: color),
          '${item.name} (${item.rarity.label})',
          color: color,
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _row(Widget icon, String text, {Color color = Palette.text}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            icon,
            const SizedBox(width: Space.sm),
            Flexible(
              child: Text(
                text,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
}

/// Celebrates a reward plus any achievements/milestones unlocked with it.
Future<void> showRewardDialog(
  BuildContext context, {
  required String title,
  required Reward reward,
  List<Unlock> unlocks = const [],
  List<String> lines = const [],
  String icon = 'open-chest',
}) {
  context.appRead.sound.play(unlocks.isEmpty ? Sfx.reward : Sfx.achievement);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      title: Column(
        children: [
          _Pop(child: GameIcon(icon, size: 56, color: Palette.gold)),
          const SizedBox(height: Space.sm),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: const TextStyle(color: Palette.textDim),
                ),
              ),
            if (!reward.isEmpty) ...[
              const SizedBox(height: Space.sm),
              RewardList(reward),
            ],
            for (final unlock in unlocks) ...[
              const SizedBox(height: Space.md),
              Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: Palette.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(
                    color: Palette.gold.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GameIcon(unlock.icon, size: 22, color: Palette.gold),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            unlock.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Palette.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unlock.description,
                      style: const TextStyle(
                        color: Palette.textDim,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RewardList(unlock.reward),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Awesome!'),
        ),
      ],
    ),
  );
}

class _Pop extends StatelessWidget {
  const _Pop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.4, end: 1),
    duration: const Duration(milliseconds: 500),
    curve: Curves.elasticOut,
    builder: (context, s, child) => Transform.scale(scale: s, child: child),
    child: child,
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Palette.danger,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
