import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../audio/sound_service.dart';
import '../widgets/game_icon.dart';
import '../theme/tokens.dart';
import 'adventure/map_screen.dart';
import 'food/food_screen.dart';
import 'home/home_screen.dart';
import 'pet/pet_screen.dart';
import 'train/train_screen.dart';

/// Main tabs. Each tab keeps its scroll position (IndexedStack).
class Shell extends StatefulWidget {
  const Shell({super.key});

  static final tabController = ValueNotifier<int>(0);

  /// Switches tab from anywhere (e.g. Home shortcuts).
  static void goTo(int index) => tabController.value = index;

  static const home = 0;
  static const food = 1;
  static const train = 2;
  static const pet = 3;
  static const adventure = 4;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Browsers block audio until the first tap; tab taps retry there.
      context.appRead.sound.startMusic();
      final warning = context.appRead.loadWarning;
      if (warning != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(warning)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Shell.tabController,
      builder: (context, index, _) => Scaffold(
        body: IndexedStack(
          index: index,
          children: const [
            HomeScreen(),
            FoodScreen(),
            TrainScreen(),
            PetScreen(),
            MapScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            final app = context.appRead;
            app.sound.play(Sfx.tap);
            app.sound.startMusic();
            Shell.goTo(i);
          },
          destinations: [
            _dest('Home', 'castle'),
            _dest('Food', 'fruit-bowl'),
            _dest('Train', 'weight-lifting'),
            _dest('Pet', 'heart-plus'),
            _dest('Adventure', 'treasure-map'),
          ],
        ),
      ),
    );
  }

  NavigationDestination _dest(String label, String icon) =>
      NavigationDestination(
        label: label,
        icon: GameIcon(icon, size: 24, color: Palette.textDim),
        selectedIcon: GameIcon(icon, size: 24, color: Palette.gold),
      );
}
