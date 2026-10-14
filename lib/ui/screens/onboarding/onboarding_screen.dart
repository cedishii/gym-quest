import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../audio/sound_service.dart';
import '../../../config/app_config.dart';
import '../../../domain/combat/element.dart';
import '../../../domain/pet/species.dart';
import '../../theme/tokens.dart';
import '../../widgets/feedback.dart';
import '../../widgets/game_icon.dart';
import '../../widgets/panel.dart';
import '../../widgets/pet_sprite.dart';
import 'profile_form.dart';

/// First run: about you -> training -> choose your pet.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _draft = ProfileDraft();
  final _petName = TextEditingController();
  final _petScroll = ScrollController();
  int _step = 0;
  PetElement? _element;
  String? _petNameError;

  @override
  void dispose() {
    _draft.dispose();
    _petName.dispose();
    _petScroll.dispose();
    super.dispose();
  }

  void _next() {
    final app = context.appRead;
    app.sound.startMusic(); // browsers only allow audio after a tap
    if (_step == 1 && !_draft.validateBody()) {
      app.sound.play(Sfx.error);
      setState(() {});
      return;
    }
    app.sound.play(Sfx.confirm);
    setState(() => _step++);
  }

  /// Selects a pet, pre-fills its species name (unless the user typed their
  /// own) and scrolls the name field into view.
  void _pick(Species species) {
    context.appRead.sound.play(Sfx.select);
    final previous = _element == null ? null : Species.of(_element!).name;
    setState(() {
      _element = species.element;
      if (_petName.text.trim().isEmpty || _petName.text == previous) {
        _petName.text = species.name;
      }
      _petNameError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_petScroll.hasClients) {
        _petScroll.animateTo(
          _petScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _back() {
    context.appRead.sound.play(Sfx.back);
    setState(() => _step--);
  }

  void _finish() {
    final element = _element;
    if (element == null) {
      showMessage(context, 'Choose a partner first.', error: true);
      return;
    }
    final name = _petName.text.trim();
    if (name.isEmpty) {
      setState(() => _petNameError = 'Name your pet');
      showMessage(context, 'Give your pet a name first.', error: true);
      return;
    }
    runAction(context, () {
      context.appRead.completeOnboarding(
        profile: _draft.build(),
        element: element,
        petName: name,
      );
      context.appRead.sound.play(Sfx.reward);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_welcome(), _body(), _training(), _pet()];
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF221B44), Palette.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_step > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.sm,
                    Space.sm,
                    Space.lg,
                    0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            for (var i = 1; i < pages.length; i++)
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i <= _step
                                        ? Palette.gold
                                        : Palette.surfaceHigh,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: pages[_step],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scroll({
    required String title,
    required String subtitle,
    required Widget child,
    required Widget action,
    ScrollController? controller,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.lg,
                  Space.lg,
                  Space.lg,
                ),
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: Space.xs),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Palette.textDim),
                  ),
                  const SizedBox(height: Space.lg),
                  child,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: SizedBox(width: double.infinity, child: action),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            children: [
              const Spacer(),
              ClipOval(
                child: Image.asset(
                  'assets/branding/logo.png',
                  width: 260,
                  height: 260,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(height: Space.xl),
              Text(
                AppConfig.appName,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Palette.gold,
                ),
              ),
              const SizedBox(height: Space.sm),
              const Text(
                'Train for real. Feed your pet with every workout.\nGrow stronger together and conquer the gym leaders.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Palette.textDim,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('start'),
                  onPressed: _next,
                  child: const Text('Begin your quest'),
                ),
              ),
              const SizedBox(height: Space.sm),
              const Text(
                'Everything stays on this device.',
                style: TextStyle(color: Palette.textFaint, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() => _scroll(
    title: 'About you',
    subtitle: 'Used to estimate your calorie needs (BMI, BMR and TDEE).',
    child: StatefulBuilder(
      builder: (context, set) =>
          BodyFields(draft: _draft, onChanged: () => set(() {})),
    ),
    action: FilledButton(
      key: const Key('next-body'),
      onPressed: _next,
      child: const Text('Next'),
    ),
  );

  Widget _training() => _scroll(
    title: 'Your training',
    subtitle:
        'Your weekly plan is built from these. You can change them any time.',
    child: StatefulBuilder(
      builder: (context, set) =>
          TrainingFields(draft: _draft, onChanged: () => set(() {})),
    ),
    action: FilledButton(
      key: const Key('next-training'),
      onPressed: _next,
      child: const Text('Next'),
    ),
  );

  Widget _pet() => _scroll(
    controller: _petScroll,
    title: 'Choose your partner',
    subtitle: 'Your pet grows from the food you earn by working out. Each element beats others in battle.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth > 460 ? 3 : 2;
            final width = (c.maxWidth - (columns - 1) * Space.sm) / columns;
            return Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final s in Species.all)
                  SizedBox(
                    width: width,
                    child: _PetCard(
                      species: s,
                      selected: _element == s.element,
                      onTap: () => _pick(s),
                    ),
                  ),
              ],
            );
          },
        ),
        if (_element != null) ...[
          const SizedBox(height: Space.md),
          _MatchupNote(element: _element!),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('field-pet-name'),
            controller: _petName,
            maxLength: 16,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Pet name',
              hintText: Species.of(_element!).name,
              errorText: _petNameError,
              counterText: '',
            ),
            onChanged: (_) {
              if (_petNameError != null) setState(() => _petNameError = null);
            },
          ),
        ],
      ],
    ),
    action: FilledButton(
      key: const Key('finish'),
      onPressed: _finish,
      child: const Text('Start adventure'),
    ),
  );
}

class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.species,
    required this.selected,
    required this.onTap,
  });

  final Species species;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Palette.element(species.element);
    return Panel(
      key: Key('pet-${species.element.name}'),
      onTap: onTap,
      padding: const EdgeInsets.all(Space.md),
      borderColor: selected ? color : Palette.border,
      glow: selected ? color : null,
      gradient: selected
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.22), Palette.surface],
            )
          : null,
      child: Column(
        children: [
          PetSprite(
            element: species.element,
            level: 1,
            size: 96,
            fixedScale: 0.95,
            animate: selected,
          ),
          const SizedBox(height: Space.xs),
          Text(
            species.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          ElementBadge(species.element, compact: true),
          const SizedBox(height: 6),
          Text(
            species.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Palette.textDim, fontSize: 12),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MatchupNote extends StatelessWidget {
  const _MatchupNote({required this.element});

  final PetElement element;

  @override
  Widget build(BuildContext context) {
    final strong = Matchups.strongAgainst(element);
    final weak = Matchups.weakAgainst(element);
    String list(List<PetElement> l) =>
        l.isEmpty ? 'nothing' : l.map((e) => e.label).join(', ');
    return Panel(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          GameIcon(
            elementIcon(element),
            size: 28,
            color: Palette.element(element),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              'Strong against ${list(strong)}.\nWeak against ${list(weak)}.',
              style: const TextStyle(color: Palette.textDim, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
