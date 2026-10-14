import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_rpg/app/app_scope.dart';
import 'package:gym_rpg/data/persistence/save_store.dart';
import 'package:gym_rpg/state/app_state.dart';
import 'package:gym_rpg/ui/screens/adventure/battle_screen.dart';
import 'package:gym_rpg/ui/theme/theme.dart';

import '../helpers.dart';

void main() {
  testWidgets(
    'battle UI plays to victory, grants rewards and unlocks the next stage',
    (tester) async {
      tester.view.physicalSize = const Size(430 * 3, 932 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final onboarded = (await tester.runAsync(() => newOnboardedState()))!;
      // A strong pet so the test battle ends in a few turns.
      final state = AppState(
        save: onboarded.save.copyWith(pet: onboarded.pet!.copyWith(level: 8)),
        store: MemorySaveStore(),
        exercises: loadExercises(),
      );

      await tester.pumpWidget(
        AppScope(
          state: state,
          services: Services(),
          child: MaterialApp(
            theme: buildTheme(),
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute(builder: (_) => const BattleScreen.stage(0)),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('move-blast')), findsOneWidget);
      expect(find.byKey(const Key('move-ultimate')), findsOneWidget);

      double arenaX(Finder f) => tester.getTopLeft(f).dx;
      final enemyX = arenaX(find.text('Wild Sproutle').first);

      for (var turn = 0; turn < 20 && !state.mapProgress.isCleared(0); turn++) {
        await tester.tap(find.byKey(const Key('move-strike')));
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        // Regression: the arena must not collapse/shift after hit effects.
        if (!state.mapProgress.isCleared(0)) {
          expect(arenaX(find.text('Wild Sproutle').first), enemyX);
        }
      }

      expect(state.mapProgress.isCleared(0), isTrue);
      expect(state.mapProgress.isUnlocked(1), isTrue);
      expect(state.save.battles.single.won, isTrue);
      expect(find.text('Victory!'), findsOneWidget);
      expect(state.inventory, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
