import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_rpg/app/app.dart';
import 'package:gym_rpg/app/app_scope.dart';
import 'package:gym_rpg/data/nutrition/usda_catalog.dart';
import 'package:gym_rpg/data/persistence/save_store.dart';
import 'package:gym_rpg/domain/pet/pet_food.dart';
import 'package:gym_rpg/state/app_state.dart';
import 'package:gym_rpg/ui/screens/shell.dart';

import '../helpers.dart';

/// Pets bob forever, so pumpAndSettle would never finish: pump a fixed
/// number of frames instead.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Drives the real UI: onboarding -> log food -> workout -> reward -> feed.
void main() {
  testWidgets('first-milestone journey through the UI', (tester) async {
    tester.view.physicalSize = const Size(430 * 3, 932 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final store = MemorySaveStore();
    late AppState state;
    await tester.runAsync(() async {
      state = await AppState.load(store: store, exercises: loadExercises());
    });
    final foods = UsdaCatalog.parseJson(
      File('assets/data/foods_usda.json').readAsStringSync(),
    );
    final services = Services(loadUsda: () async => UsdaCatalog(foods));
    Shell.goTo(Shell.home);

    await tester.pumpWidget(GymQuestApp(state: state, services: services));
    await settle(tester);

    // --- Onboarding.
    await tester.tap(find.byKey(const Key('start')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('field-name')), 'Cedrick');
    await tester.enterText(find.byKey(const Key('field-age')), '24');
    await tester.enterText(find.byKey(const Key('field-height')), '170');
    await tester.enterText(find.byKey(const Key('field-weight')), '68');
    await tester.tap(find.byKey(const Key('next-body')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('next-training')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('pet-leaf')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('field-pet-name')), 'Sprig');
    await tester.ensureVisible(find.byKey(const Key('finish')));
    await tester.tap(find.byKey(const Key('finish')));
    await tester.pump(const Duration(milliseconds: 600));

    expect(state.save.onboarded, isTrue);
    expect(state.pet!.name, 'Sprig');
    expect(find.text('Hi, Cedrick'), findsOneWidget);

    // --- Food: search the offline list and log a portion.
    Shell.goTo(Shell.food);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('add-food')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('food-query')),
      'rice white long-grain cooked',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.textContaining('Rice, white, long-grain').first);
    await settle(tester);
    await tester.tap(find.byKey(const Key('log-food')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.entriesFor(state.today), hasLength(1));
    expect(state.totalsFor(state.today).kcal, greaterThan(100));
    await settle(tester);
    await tester.pump(const Duration(seconds: 3)); // let the snackbar leave

    // --- Workout: start day 1, complete one set, finish.
    Shell.goTo(Shell.train);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('day-0')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('start-workout')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
    expect(state.activeSession, isNotNull);

    await tester.tap(find.byKey(const Key('done-0-0')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.activeSession!.completedSets, 1);

    final kibbleBefore = state.foodCount(PetFood.kibble);
    await tester.tap(find.byKey(const Key('finish-workout')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Finish'),
      ),
    ); // confirm early finish
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Workout complete!'), findsOneWidget);
    expect(state.save.workouts, hasLength(1));
    expect(state.foodCount(PetFood.kibble), greaterThan(kibbleBefore));
    await tester.tap(find.text('Awesome!'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    // --- Pet: feed a kibble and gain XP.
    Shell.goTo(Shell.pet);
    await tester.pump(const Duration(milliseconds: 300));
    final xpBefore = state.pet!.level * 100000 + state.pet!.xp;
    await tester.tap(find.byKey(const Key('feed-kibble')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(state.pet!.level * 100000 + state.pet!.xp, greaterThan(xpBefore));

    // Everything was written to the store.
    await tester.runAsync(() => state.flush());
    final reloaded = await tester.runAsync(
      () => AppState.load(store: store, exercises: loadExercises()),
    );
    expect(reloaded!.save.workouts, hasLength(1));
    expect(reloaded.entriesFor(state.today), hasLength(1));
    expect(reloaded.pet!.xp, state.pet!.xp);

    // Let looping animations stop before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
