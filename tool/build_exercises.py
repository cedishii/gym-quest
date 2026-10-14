"""Builds assets/data/exercises.json and assets/exercises/<id>/<n>.jpg from
free-exercise-db (https://github.com/yuhonas/free-exercise-db, Unlicense /
public domain).

Only a curated subset is bundled so the app stays small and works offline.
Each exercise is tagged with the extra fields the workout planner needs:
  "pattern"    movement slot used by the planner (squat, push, pull, ...)
  "lowImpact"  safe for beginners with a high BMI (no jumping/running)
  "timed"      logged as seconds instead of reps
  "met"        MET value from the Compendium of Physical Activities (estimate)

Usage:
    python tool/build_exercises.py <exercises.json from free-exercise-db dist/>
"""

import json
import os
import sys
import urllib.request

IMAGE_BASE = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

# id -> (pattern, lowImpact, timed, MET)
# MET values: Compendium of Physical Activities (2011/2024 adult compendium):
# resistance training, moderate effort ~3.5-5.0; calisthenics vigorous ~8.0;
# stretching ~2.3; running/jumping ~8-10. These are estimates.
CURATED = {
    # squat / knee dominant
    "Bodyweight_Squat": ("squat", True, False, 5.0),
    "Goblet_Squat": ("squat", True, False, 5.0),
    "Barbell_Squat": ("squat", False, False, 6.0),
    "Dumbbell_Lunges": ("squat", False, False, 5.0),
    "Bodyweight_Walking_Lunge": ("squat", False, False, 5.0),
    "Leg_Press": ("squat", True, False, 5.0),
    "Dumbbell_Step_Ups": ("squat", True, False, 5.0),
    "Freehand_Jump_Squat": ("squat", False, False, 8.0),
    "Split_Squat_with_Dumbbells": ("squat", False, False, 5.0),
    # hinge / hip dominant
    "Butt_Lift_Bridge": ("hinge", True, False, 3.5),
    "Romanian_Deadlift": ("hinge", False, False, 6.0),
    "Barbell_Deadlift": ("hinge", False, False, 6.0),
    "Stiff-Legged_Dumbbell_Deadlift": ("hinge", False, False, 5.0),
    "Kettlebell_One-Legged_Deadlift": ("hinge", False, False, 5.0),
    "One-Arm_Kettlebell_Swings": ("hinge", False, False, 8.0),
    "Barbell_Hip_Thrust": ("hinge", True, False, 5.0),
    "Lying_Leg_Curls": ("hinge", True, False, 4.0),
    # horizontal push
    "Pushups": ("push", True, False, 8.0),
    "Incline_Push-Up": ("push", True, False, 5.0),
    "Push-Ups_With_Feet_Elevated": ("push", False, False, 8.0),
    "Dumbbell_Bench_Press": ("push", True, False, 5.0),
    "Barbell_Bench_Press_-_Medium_Grip": ("push", False, False, 6.0),
    "Incline_Dumbbell_Press": ("push", True, False, 5.0),
    "Dips_-_Triceps_Version": ("push", False, False, 8.0),
    # vertical push
    "Standing_Dumbbell_Press": ("press", True, False, 5.0),
    "Seated_Dumbbell_Press": ("press", True, False, 5.0),
    "Standing_Military_Press": ("press", False, False, 6.0),
    "Side_Lateral_Raise": ("press", True, False, 3.5),
    "Arnold_Dumbbell_Press": ("press", False, False, 5.0),
    # pull
    "Pullups": ("pull", False, False, 8.0),
    "Chin-Up": ("pull", False, False, 8.0),
    "Wide-Grip_Lat_Pulldown": ("pull", True, False, 5.0),
    "Seated_Cable_Rows": ("pull", True, False, 5.0),
    "One-Arm_Dumbbell_Row": ("pull", True, False, 5.0),
    "Bent_Over_Barbell_Row": ("pull", False, False, 6.0),
    "Inverted_Row": ("pull", True, False, 6.0),
    "Face_Pull": ("pull", True, False, 3.5),
    "Band_Pull_Apart": ("pull", True, False, 3.5),
    # arms
    "Dumbbell_Bicep_Curl": ("arms", True, False, 3.5),
    "Hammer_Curls": ("arms", True, False, 3.5),
    "Barbell_Curl": ("arms", True, False, 3.5),
    "Triceps_Pushdown": ("arms", True, False, 3.5),
    "Bench_Dips": ("arms", True, False, 5.0),
    "Standing_Dumbbell_Triceps_Extension": ("arms", True, False, 3.5),
    # core
    "Plank": ("core", True, True, 4.0),
    "Crunches": ("core", True, False, 3.8),
    "Russian_Twist": ("core", True, False, 3.8),
    "Dead_Bug": ("core", True, False, 3.8),
    "Flat_Bench_Lying_Leg_Raise": ("core", True, False, 3.8),
    "Hanging_Leg_Raise": ("core", False, False, 4.0),
    "Mountain_Climbers": ("core", False, True, 8.0),
    "Side_Bridge": ("core", True, True, 4.0),
    "Ab_Roller": ("core", False, False, 4.0),
    # conditioning / cardio
    "Jogging_Treadmill": ("cardio", False, True, 7.0),
    "Walking_Treadmill": ("cardio", True, True, 3.5),
    "Bicycling_Stationary": ("cardio", True, True, 6.8),
    "Rowing_Stationary": ("cardio", True, True, 7.0),
    "Elliptical_Trainer": ("cardio", True, True, 5.0),
    "Rope_Jumping": ("cardio", False, True, 11.0),
    "Step_Mill": ("cardio", True, True, 9.0),
    "Star_Jump": ("cardio", False, False, 8.0),
    "Trail_Running_Walking": ("cardio", True, True, 4.5),
    "Fast_Skipping": ("cardio", False, True, 8.0),
    # mobility
    "Cat_Stretch": ("mobility", True, True, 2.3),
    "Childs_Pose": ("mobility", True, True, 2.3),
    "Hamstring_Stretch": ("mobility", True, True, 2.3),
    "Standing_Hip_Circles": ("mobility", True, True, 2.3),
    "Chest_Stretch_on_Stability_Ball": ("mobility", True, True, 2.3),
    "Worlds_Greatest_Stretch": ("mobility", True, True, 2.3),
}


def main(src):
    with open(src, encoding="utf-8") as handle:
        db = {item["id"]: item for item in json.load(handle)}

    root = os.path.join(os.path.dirname(__file__), "..", "assets")
    out, missing = [], []
    for ex_id, (pattern, low_impact, timed, met) in CURATED.items():
        item = db.get(ex_id)
        if item is None:
            missing.append(ex_id)
            continue
        images = []
        for index, rel in enumerate(item.get("images", [])[:2]):
            local = f"assets/exercises/{ex_id}/{index}.jpg"
            target = os.path.join(root, "..", local)
            if not os.path.exists(target):
                os.makedirs(os.path.dirname(target), exist_ok=True)
                urllib.request.urlretrieve(IMAGE_BASE + rel, target)
            images.append(local)
        out.append({
            "id": ex_id,
            "name": item["name"],
            "category": item.get("category"),
            "equipment": item.get("equipment") or "body only",
            "level": item.get("level"),
            "primaryMuscles": item.get("primaryMuscles", []),
            "secondaryMuscles": item.get("secondaryMuscles", []),
            "instructions": item.get("instructions", []),
            "images": images,
            "pattern": pattern,
            "lowImpact": low_impact,
            "timed": timed,
            "met": met,
        })

    target = os.path.join(root, "data", "exercises.json")
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8") as handle:
        json.dump({"source": "free-exercise-db by yuhonas (Unlicense, public domain)",
                   "exercises": out}, handle, ensure_ascii=False, indent=1)
    print(f"wrote {len(out)} exercises")
    if missing:
        print("not found in free-exercise-db:", ", ".join(missing))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
