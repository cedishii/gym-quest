"""Builds assets/data/foods_usda.json from the USDA FoodData Central
SR Legacy CSV download (public domain, CC0 1.0).

Usage:
    python tool/build_usda_foods.py <path to FoodData_Central_sr_legacy_food_csv_2018-04>

Download: https://fdc.nal.usda.gov/download-datasets/ (SR Legacy, CSV).

Output format (compact keys keep the bundled file small):
    {"source": ..., "foods": [{"id", "n" name, "c" category,
      "k" kcal/100 g, "p" protein g, "f" fat g, "cb" carbs g, "fb" fiber g,
      "s" [[portion label, grams], ...]}]}
"""

import csv
import json
import os
import sys

ENERGY_KCAL = "1008"
PROTEIN = "1003"
FAT = "1004"
CARBS = "1005"
FIBER = "1079"
WANTED = {ENERGY_KCAL, PROTEIN, FAT, CARBS, FIBER}

# Categories that are not useful for a personal food log.
SKIPPED_CATEGORIES = {"Baby Foods", "Quality Control Materials",
                      "American Indian/Alaska Native Foods"}


def read(path):
    with open(path, newline="", encoding="utf-8") as handle:
        yield from csv.DictReader(handle)


def main(src):
    categories = {row["id"]: row["description"]
                  for row in read(os.path.join(src, "food_category.csv"))}
    units = {row["id"]: row["name"]
             for row in read(os.path.join(src, "measure_unit.csv"))}

    foods = {}
    for row in read(os.path.join(src, "food.csv")):
        category = categories.get(row["food_category_id"], "")
        if category in SKIPPED_CATEGORIES:
            continue
        foods[row["fdc_id"]] = {"id": int(row["fdc_id"]),
                                "n": row["description"].strip(),
                                "c": category, "s": []}

    nutrients = {}
    for row in read(os.path.join(src, "food_nutrient.csv")):
        if row["nutrient_id"] in WANTED and row["fdc_id"] in foods:
            nutrients.setdefault(row["fdc_id"], {})[row["nutrient_id"]] = float(row["amount"])

    for row in read(os.path.join(src, "food_portion.csv")):
        food = foods.get(row["fdc_id"])
        if food is None or not row["gram_weight"]:
            continue
        grams = float(row["gram_weight"])
        if grams <= 0:
            continue
        amount = row["amount"] or "1"
        unit = units.get(row["measure_unit_id"], "")
        unit = "" if unit == "undetermined" else unit
        label = " ".join(part for part in [_trim(amount), unit,
                                           row["modifier"].strip(),
                                           row["portion_description"].strip()] if part)
        if len(food["s"]) < 4:
            food["s"].append([label[:60], round(grams, 1)])

    out = []
    for fdc_id, food in foods.items():
        values = nutrients.get(fdc_id, {})
        if ENERGY_KCAL not in values:
            continue  # without energy the entry is useless for calorie tracking
        food["k"] = round(values[ENERGY_KCAL], 1)
        food["p"] = round(values.get(PROTEIN, 0.0), 2)
        food["f"] = round(values.get(FAT, 0.0), 2)
        food["cb"] = round(values.get(CARBS, 0.0), 2)
        food["fb"] = round(values.get(FIBER, 0.0), 2)
        out.append(food)

    out.sort(key=lambda f: f["n"].lower())
    target = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "foods_usda.json")
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8") as handle:
        json.dump({"source": "USDA FoodData Central, SR Legacy (April 2018). Public domain (CC0 1.0).",
                   "basis": "per 100 g",
                   "foods": out}, handle, ensure_ascii=False, separators=(",", ":"))
    print(f"wrote {len(out)} foods to {os.path.normpath(target)}")


def _trim(amount):
    try:
        value = float(amount)
    except ValueError:
        return amount
    return str(int(value)) if value.is_integer() else str(value)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
