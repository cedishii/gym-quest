import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_scope.dart';
import 'audio/sound_service.dart';
import 'data/exercise/exercise_repository.dart';
import 'data/persistence/save_store.dart';
import 'state/app_state.dart';
import 'ui/theme/theme.dart';
import 'ui/theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Boot());
}

/// Shows a splash while the save and bundled data load, and a readable
/// error (instead of a blank screen) if loading fails.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  late Future<AppState> _loading = _load();
  final _services = Services();

  static Future<AppState> _load() async {
    final exercises = await ExerciseRepository.load();
    return AppState.load(
      store: createPlatformSaveStore(),
      exercises: exercises,
      sound: GameSound(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppState>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return GymQuestApp(state: snapshot.data!, services: _services);
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: Scaffold(
            body: Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Palette.danger,
                            size: 48,
                          ),
                          const SizedBox(height: Space.md),
                          Text(
                            'Could not start: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Space.md),
                          FilledButton(
                            onPressed: () => setState(() => _loading = _load()),
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(color: Palette.gold),
            ),
          ),
        );
      },
    );
  }
}
