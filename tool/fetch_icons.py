"""Downloads the game-icons.net SVGs used by the app into assets/icons/.

Source: https://github.com/game-icons/icons
License: CC BY 3.0 (Zeromancer icons: CC0). Each author is credited in
assets/credits/asset_manifest.json and on the in-app Credits screen.

The black square background path is removed and the fill left white so the
app can tint icons with a ColorFilter.

Usage:
    python tool/fetch_icons.py
"""

import json
import os
import re
import urllib.request

BASE = "https://raw.githubusercontent.com/game-icons/icons/master/"

# local name -> repository path
ICONS = {
    # equipment
    "visored-helm": "lorc/visored-helm.svg",
    "barbute": "lorc/barbute.svg",
    "crested-helmet": "lorc/crested-helmet.svg",
    "leather-armor": "delapouite/leather-armor.svg",
    "breastplate": "lorc/breastplate.svg",
    "chest-armor": "delapouite/chest-armor.svg",
    "boots": "lorc/boots.svg",
    "leather-boot": "lorc/leather-boot.svg",
    "walking-boot": "lorc/walking-boot.svg",
    "ring": "delapouite/ring.svg",
    "diamond-ring": "delapouite/diamond-ring.svg",
    "power-ring": "delapouite/power-ring.svg",
    "gem-pendant": "lorc/gem-pendant.svg",
    "gauntlet": "delapouite/gauntlet.svg",
    # elements
    "el-fire": "sbed/fire.svg",
    "el-water": "sbed/water-drop.svg",
    "el-leaf": "lorc/three-leaves.svg",
    "el-rock": "john-redman/rock.svg",
    "el-neutral": "lorc/rolling-energy.svg",
    # pet food
    "meat": "lorc/meat.svg",
    "steak": "delapouite/steak.svg",
    "fruit-bowl": "skoll/fruit-bowl.svg",
    "carrot": "delapouite/carrot.svg",
    # game ui
    "trophy": "lorc/trophy.svg",
    "medal": "lorc/medal.svg",
    "laurels": "lorc/laurels.svg",
    "star-medal": "delapouite/star-medal.svg",
    "crown": "lorc/crown.svg",
    "castle": "lorc/castle.svg",
    "stone-tower": "lorc/stone-tower.svg",
    "treasure-map": "lorc/treasure-map.svg",
    "chest": "delapouite/chest.svg",
    "open-chest": "skoll/open-treasure-chest.svg",
    "crossed-swords": "lorc/crossed-swords.svg",
    "weight-lifting": "delapouite/weight-lifting-up.svg",
    "biceps": "delapouite/biceps.svg",
    "run": "lorc/run.svg",
    "fist": "lorc/fist.svg",
    "heart-plus": "zeromancer/heart-plus.svg",
    "backpack": "delapouite/backpack.svg",
    "shield": "sbed/shield.svg",
    "swords-power": "delapouite/swords-power.svg",
    "lightning": "lorc/lightning-helix.svg",
    "footprint": "lorc/footprint.svg",
    "flag": "delapouite/flag-objective.svg",
    "book": "lorc/book-cover.svg",
    "flame": "carl-olsen/flame.svg",
}

AUTHORS = {
    "lorc": ("Lorc", "CC BY 3.0"),
    "delapouite": ("Delapouite", "CC BY 3.0"),
    "sbed": ("Sbed", "CC BY 3.0"),
    "john-redman": ("John Redman", "CC BY 3.0"),
    "skoll": ("Skoll", "CC BY 3.0"),
    "carl-olsen": ("Carl Olsen", "CC BY 3.0"),
    "zeromancer": ("Zeromancer", "CC0"),
}


def main():
    root = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
    os.makedirs(root, exist_ok=True)
    used = {}
    for name, path in ICONS.items():
        with urllib.request.urlopen(BASE + path) as response:
            svg = response.read().decode("utf-8")
        svg = svg.replace('<path d="M0 0h512v512H0z"/>', "")
        svg = re.sub(r'fill="#fff"', 'fill="#ffffff"', svg)
        with open(os.path.join(root, name + ".svg"), "w", encoding="utf-8") as handle:
            handle.write(svg)
        author = path.split("/")[0]
        used.setdefault(author, []).append(name)
    with open(os.path.join(root, "_authors.json"), "w", encoding="utf-8") as handle:
        json.dump({AUTHORS[a][0]: {"license": AUTHORS[a][1], "icons": sorted(n)}
                   for a, n in sorted(used.items())}, handle, indent=1)
    print(f"wrote {len(ICONS)} icons")


if __name__ == "__main__":
    main()
