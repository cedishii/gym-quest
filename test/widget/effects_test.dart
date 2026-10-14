import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_rpg/domain/combat/element.dart';
import 'package:gym_rpg/ui/widgets/battle_effects.dart';
import 'package:gym_rpg/ui/widgets/pet_sprite.dart';

void main() {
  testWidgets('every element and attack size plays its effect and finishes', (
    tester,
  ) async {
    for (final element in PetElement.values) {
      for (final kind in ImpactKind.values) {
        var done = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: ImpactEffect(
                key: ValueKey('$element-$kind'),
                element: element,
                kind: kind,
                size: 200,
                onDone: () => done = true,
              ),
            ),
          ),
        );
        for (var i = 0; i < 14; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(done, isTrue, reason: '$element $kind');
      }
    }
  });

  testWidgets('pets render at every aura tier', (tester) async {
    for (final level in [1, 10, 20, 30, 45]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: PetSprite(element: PetElement.leaf, level: level),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(PetSprite), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
