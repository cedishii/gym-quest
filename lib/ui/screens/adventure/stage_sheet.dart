import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../domain/combat/element.dart';
import '../../../domain/map/stages.dart';
import '../../theme/tokens.dart';
import '../../widgets/feedback.dart';
import '../../widgets/game_icon.dart';
import '../../widgets/pet_sprite.dart';
import 'battle_screen.dart';

Future<void> showStageSheet(BuildContext context, Stage stage) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StageSheet(stage: stage),
    );

class _StageSheet extends StatelessWidget {
  const _StageSheet({required this.stage});

  final Stage stage;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pet = app.pet!;
    final progress = app.mapProgress;
    final unlocked = progress.isUnlocked(stage.index);
    final cleared = progress.isCleared(stage.index);
    final enemy = stage.enemy();
    final ours = Matchups.multiplier(pet.element, stage.element);
    final theirs = Matchups.multiplier(stage.element, pet.element);
    final levelGap = pet.level - stage.level;

    String hint;
    Color hintColor;
    if (ours > 1 && theirs <= 1) {
      hint = '${pet.species.blastName} is super effective here!';
      hintColor = Palette.hp;
    } else if (theirs > 1) {
      hint =
          '${stage.element.label} is strong against your ${pet.element.label} pet. Strike, guard and gear up.';
      hintColor = Palette.danger;
    } else if (ours < 1) {
      hint = 'Your element attacks are weak here; Strike deals normal damage.';
      hintColor = Palette.warning;
    } else {
      hint = 'An even matchup.';
      hintColor = Palette.textDim;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (stage.portrait != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: Image.asset(
                      stage.portrait!,
                      width: 96,
                      height: 112,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.7),
                    ),
                  )
                else
                  PetSprite(
                    element: stage.element,
                    level: 1,
                    size: 100,
                    fixedScale: 0.95,
                    showAura: false,
                  ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        switch (stage.kind) {
                          StageKind.wild => 'WILD ENCOUNTER',
                          StageKind.trainer => 'TRAINER BATTLE',
                          StageKind.leader => 'GYM LEADER',
                        },
                        style: TextStyle(
                          color: Palette.element(stage.element),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        stage.opponentName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${enemy.name} · Lv ${stage.level}',
                        style: const TextStyle(color: Palette.textDim),
                      ),
                      const SizedBox(height: 6),
                      ElementBadge(stage.element, compact: true),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Container(
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(
                color: Palette.surfaceHigh,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hint, style: TextStyle(color: hintColor)),
                  const SizedBox(height: 4),
                  Text(
                    levelGap >= 0
                        ? '${pet.name} is Lv ${pet.level} (${levelGap == 0 ? 'same level' : '$levelGap above'}).'
                        : '${pet.name} is Lv ${pet.level}, ${-levelGap} below. Work out and feed your pet to catch up!',
                    style: const TextStyle(
                      color: Palette.textDim,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            if (cleared)
              const Text(
                'Cleared. Rematches are practice only (no rewards).',
                style: TextStyle(color: Palette.textDim),
              )
            else ...[
              const Text(
                'FIRST-CLEAR REWARD',
                style: TextStyle(
                  color: Palette.textDim,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: Space.xs),
              RewardList(stage.reward),
              if (stage.kind == StageKind.leader)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const GameIcon('medal', size: 22, color: Palette.gold),
                      const SizedBox(width: Space.sm),
                      Text(
                        stage.region.badgeName,
                        style: const TextStyle(
                          color: Palette.gold,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: Space.lg),
            FilledButton.icon(
              key: const Key('battle'),
              onPressed: unlocked
                  ? () {
                      app.sound.play(Sfx.confirm);
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => BattleScreen.stage(stage.index),
                        ),
                      );
                    }
                  : null,
              icon: const GameIcon(
                'crossed-swords',
                size: 20,
                color: Color(0xFF231A05),
              ),
              label: Text(
                unlocked
                    ? (cleared ? 'Practice battle' : 'Battle!')
                    : 'Locked: clear the previous stage',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
