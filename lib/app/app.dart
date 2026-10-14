import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../state/app_state.dart';
import '../ui/screens/onboarding/onboarding_screen.dart';
import '../ui/screens/shell.dart';
import '../ui/theme/theme.dart';
import 'app_scope.dart';

class GymQuestApp extends StatelessWidget {
  const GymQuestApp({super.key, required this.state, required this.services});

  final AppState state;
  final Services services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      services: services,
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _Root(),
      ),
    );
  }
}

/// Onboarding until a profile and pet exist, then the main tabs. Also
/// pauses the music while the app is in the background.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sound = context.appRead.sound;
    switch (state) {
      case AppLifecycleState.resumed:
        sound.resumeFromBackground();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        sound.pauseForBackground();
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarded = context.app.save.onboarded;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: onboarded
          ? const Shell(key: ValueKey('shell'))
          : const OnboardingScreen(key: ValueKey('onboarding')),
    );
  }
}
