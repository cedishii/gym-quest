# Gym Quest

A personal fitness tracker wrapped in a pet RPG. Real workouts earn food,
food levels up your pet, and your pet battles its way past five elemental
gym leaders, then climbs an endless tower.

Flutter app (Android first; also runs in Chrome for quick previews).
Everything is stored locally on the device; there are no accounts and no
backend.

## Features

**Fitness**
- Profile with BMI (WHO Asia-Pacific or standard cut-offs), BMR (Mifflin-St Jeor),
  TDEE and a calorie/macro target. The target never goes below a safe floor.
- Food log with an offline database of 7,000+ USDA foods, online Open Food
  Facts search and barcode lookup, and custom foods (for home cooking).
- Rule-based weekly workout plans (full body / upper-lower / push-pull-legs) built
  from your goal, experience, equipment, days per week and BMI.
- Live workout logging with exercise photos, personal records and estimated calories.

**Game**
- Five pets (Fire, Rock, Water, Leaf, Neutral) that grow bigger and gain auras as they level.
- Workout rewards: kibble per exercise, a steak for a full workout, and a steak per
  personal record. A workout can only be rewarded once.
- Five equipment slots (helmet, armor, boots, ring, amulet) that change stats.
- Adventure map with 20 stages, five gym leaders and turn-based battles with element matchups.
- Workout streaks (one rest day between workouts is allowed), streak milestones at
  1/2/3/4 weeks and 1 month, 17 achievements, and an Endless Tower after the champion.

## Running

```sh
flutter pub get
flutter run                 # Android device or emulator
flutter run -d chrome       # quick preview in the browser
flutter test                # unit, state, asset and widget tests
dart run tool/balance_sim.dart   # pacing check: pet level needed per stage
```

## Project layout

```
lib/
  config/        balance.dart (all game numbers), app_config.dart
  core/          dates, ids, JSON helpers
  domain/        pure rules, no Flutter imports:
    profile/     BMI/BMR/TDEE and calorie targets
    nutrition/   foods, servings, log math
    workout/     exercises, planner, sessions, personal records
    pet/         species, stats, leveling
    inventory/   items and equipment bonuses
    combat/      elements, matchups, battle engine
    map/         regions, stages, endless tower
    progression/ streaks, milestones, achievements
    rewards/     workout rewards
  data/          persistence (atomic JSON file, browser storage), exercise and food sources
  state/         AppState: the single source of truth, connects every system
  ui/            theme, shared widgets, screens
  audio/         sound effects and music
assets/          art, audio, data, credits/asset_manifest.json
tool/            scripts that rebuild the bundled data and art (see below)
test/            tests
```

## Data and asset tools

Bundled data and art are generated from free sources. Re-run these when changing them:

| Script | Builds |
|---|---|
| `tool/build_usda_foods.py <SR Legacy CSV dir>` | `assets/data/foods_usda.json` |
| `tool/build_exercises.py <free-exercise-db exercises.json>` | `assets/data/exercises.json` + photos |
| `dart run tool/build_pets.dart <Monster Builder PNG/Default>` | `assets/pets/*.png` |
| `dart run tool/prepare_leaders.dart <AllAnime dir>` | `assets/leaders/*.png` |
| `python tool/fetch_icons.py` | `assets/icons/*.svg` |
| `dart run tool/build_effects.dart <Smoke Particles PNG> <Explosions Half Sized>` | `assets/fx/burst/`, `assets/fx/anim/` |
| `dart run tool/prepare_branding.dart` then `dart run flutter_launcher_icons` | logo and launcher icons |
| `python tool/build_credits.py` | `CREDITS.md` from the manifest |

Every third-party asset and library, its license and attribution is listed in
`assets/credits/asset_manifest.json` and shown on the in-app Credits screen.
When you add an asset, add it there too. `test/assets_test.dart` checks that
every referenced asset exists and is credited.

## Balancing

See [docs/BALANCE.md](docs/BALANCE.md).

## Releasing

See [docs/RELEASING.md](docs/RELEASING.md).

## Credits

Built with free and open data, art, sound and libraries. See
[CREDITS.md](CREDITS.md) for every creator and license.

## License

Code: MIT, © 2026 Cedrick Miguel P. Kaneko. Bundled third-party assets keep
their own licenses (listed in CREDITS.md).
