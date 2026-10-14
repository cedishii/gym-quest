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

/// Onboarding until a profile and pet exist, then the main tabs.
class _Root extends StatelessWidget {
  const _Root();

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
