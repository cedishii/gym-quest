import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../config/app_config.dart';
import '../../../domain/profile/fitness_calc.dart';
import '../../../domain/profile/profile.dart';
import '../../theme/tokens.dart';
import '../../widgets/feedback.dart';
import '../../widgets/game_icon.dart';
import '../../widgets/panel.dart';
import '../onboarding/profile_form.dart';
import 'achievements_screen.dart';
import 'credits_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final profile = app.profile!;
    final f = app.fitness!;
    final settings = app.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
                Text(
                  '${profile.age} yrs · ${profile.heightCm.round()} cm · ${profile.weightKg.toStringAsFixed(1)} kg · '
                  '${profile.goal.label.toLowerCase()} · ${profile.daysPerWeek} days/week',
                  style: const TextStyle(color: Palette.textDim),
                ),
              ],
            ),
          ),
          const SectionHeader('Your numbers (estimates)'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(
                  'BMI',
                  '${f.bmi.toStringAsFixed(1)} · ${f.bmiCategory.label}',
                  'weight ÷ height² (${profile.useAsianBmiCutoffs ? 'Asia-Pacific' : 'standard WHO'} cut-offs)',
                ),
                _row(
                  'BMR',
                  '${f.bmr.round()} kcal/day',
                  'Mifflin-St Jeor: calories burned at complete rest',
                ),
                _row(
                  'TDEE',
                  '${f.tdee.round()} kcal/day',
                  'BMR × ${profile.activity.factor} activity factor',
                ),
                _row(
                  'Daily target',
                  '${f.targets.calories} kcal',
                  f.floorApplied
                      ? 'raised to the safe minimum of ${f.calorieFloor} kcal'
                      : '${profile.goal.label}: ${_goalAdjust(profile.goal)}',
                ),
                _row(
                  'Macros',
                  'P ${f.targets.proteinG} g · C ${f.targets.carbsG} g · F ${f.targets.fatG} g',
                  'protein by body weight, fat 25% of calories, carbs the rest',
                ),
                const SizedBox(height: Space.sm),
                for (final note in f.notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Palette.textDim,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            note,
                            style: const TextStyle(
                              color: Palette.textDim,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.xs),
          const Text(
            'Not medical advice. For health conditions, pregnancy or big weight changes, check with a professional.',
            style: TextStyle(color: Palette.textFaint, fontSize: 11),
          ),
          const SectionHeader('Progress'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const GameIcon(
                    'trophy',
                    size: 26,
                    color: Palette.gold,
                  ),
                  title: const Text('Achievements & awards'),
                  subtitle: Text('${app.save.achievements.length} unlocked'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AchievementsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Sound'),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Music'),
                  value: settings.music,
                  onChanged: (v) {
                    app.updateSettings(settings.copyWith(music: v));
                    if (v) app.sound.startMusic();
                  },
                ),
                if (settings.music)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                    child: Slider(
                      value: settings.musicVolume,
                      onChanged: (v) =>
                          app.updateSettings(settings.copyWith(musicVolume: v)),
                    ),
                  ),
                SwitchListTile(
                  title: const Text('Sound effects'),
                  value: settings.sfx,
                  onChanged: (v) {
                    app.updateSettings(settings.copyWith(sfx: v));
                    app.sound.play(Sfx.toggle);
                  },
                ),
              ],
            ),
          ),
          const SectionHeader('About'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.favorite_outline_rounded),
                  title: const Text('Credits & licenses'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreditsScreen()),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Your data'),
                  subtitle: const Text(
                    'Stored only on this device. Online food search sends just your search words or barcode to Open Food Facts.',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.restart_alt_rounded,
                    color: Palette.danger,
                  ),
                  title: const Text(
                    'Reset everything',
                    style: TextStyle(color: Palette.danger),
                  ),
                  onTap: () async {
                    final ok = await confirm(
                      context,
                      title: 'Reset everything?',
                      message: 'Your profile, pet, food log, workouts and progress will be deleted. This cannot be undone.',
                      confirmLabel: 'Delete all',
                      destructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    await app.resetAll();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          const Center(
            child: Text(
              '${AppConfig.appName} ${AppConfig.appVersion}',
              style: TextStyle(color: Palette.textFaint, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  static String _goalAdjust(Goal goal) => switch (goal) {
    Goal.loseFat => 'TDEE − ${FitnessCalc.loseFatDeficit} kcal',
    Goal.buildMuscle => 'TDEE + ${FitnessCalc.buildMuscleSurplus} kcal',
    Goal.maintain => 'equal to TDEE',
  };

  Widget _row(String label, String value, String how) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: const TextStyle(color: Palette.textDim)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                how,
                style: const TextStyle(color: Palette.textFaint, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final ProfileDraft _draft = ProfileDraft(context.appRead.profile);

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _save() {
    if (!_draft.validateBody()) {
      setState(() {});
      context.appRead.sound.play(Sfx.error);
      return;
    }
    final app = context.appRead;
    final old = app.plan;
    app.updateProfile(_draft.build());
    app.sound.play(Sfx.confirm);
    Navigator.of(context).pop();
    showMessage(
      context,
      identical(old, app.plan)
          ? 'Profile saved'
          : 'Profile saved · new workout plan generated',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Edit profile'),
      actions: [TextButton(onPressed: _save, child: const Text('Save'))],
    ),
    body: ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        BodyFields(draft: _draft, onChanged: () => setState(() {})),
        const SectionHeader('Training'),
        TrainingFields(draft: _draft, onChanged: () => setState(() {})),
        const SizedBox(height: Space.lg),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    ),
  );
}
