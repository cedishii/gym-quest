# Balance notes

All numbers live in `lib/config/balance.dart`. These are first-pass values,
meant to be tuned after playing.

## Progression loop

workout → food → pet XP → levels/stats (+ equipment) → battles → stage unlocks

- **XP per level:** `60 + 8 × level`. Level 40 needs about 8,600 XP in total.
- **Food XP:** Kibble 25 · Steak 70 · Golden Feast 200.
- **Full 5-exercise workout at tier 1:** 5 kibble + 1 steak = 195 XP.
- **Training tier:** goes up at 12/30/60/100 workouts (or starts higher based on
  your stated experience). Each tier adds +25% kibble and more planned volume.
- **Personal records:** +1 steak each, up to 3 per workout. A record must beat the
  previous best by 2% (estimated 1RM), +1 rep or +5 s. The first time you log an
  exercise only sets your baseline.
- **No daily caps** (a design decision). Sets beyond the plan earn nothing extra,
  and each workout can only be rewarded once.

## Pacing (from `dart run tool/balance_sim.dart`)

These are the full workouts needed to reach the pet level that wins 60% of
simulated battles against each gym leader, at tier 1 with no record bonuses:

| Leader | Enemy Lv | Workouts (range by pet element) |
|---|---|---|
| Mira (Leaf) | 8 | 4–7 |
| Ren (Water) | 15 | 9–18 |
| Tomas (Rock) | 23 | 18–37 |
| Dario (Fire) | 31 | 18–44 |
| Aiko (Neutral) | 38 | 39–46 |

At 3 workouts a week, reaching the champion takes about 3–4 months. Fitter
players get there sooner through records and tiers.

Type matchups matter. A Fire pet facing the Rock leader is the steepest
gap, so that's where you'd tune first. The levers are `superEffective` /
`notVeryEffective`, `leaderStatMultiplier` and `stageEnemyLevel`.

## Endless Tower

Opens after the champion. Floor n: enemy HP × (1 + 0.06·(n−1)), and the level
rises every 3 floors. An item drops every 10 floors.
