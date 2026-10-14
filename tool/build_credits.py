"""Regenerates CREDITS.md from assets/credits/asset_manifest.json.

Usage:
    python tool/build_credits.py
"""

import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")


def main():
    with open(os.path.join(ROOT, "assets", "credits", "asset_manifest.json"), encoding="utf-8") as handle:
        manifest = json.load(handle)
    lines = [
        "# Credits",
        "",
        "Gym Quest is made by Cedrick Miguel P. Kaneko, with free and open data, art, sound "
        "and software from these generous creators. Thank you!",
        "",
        "The app logo is the project's own artwork.",
        "",
        "## Data, art, sound and fonts",
        "",
        "| What | By | License |",
        "|---|---|---|",
    ]
    for s in manifest["sources"]:
        lines.append(f"| [{s['title']}]({s['url']}) | {s['author']} | {s['license']} |")
    lines += ["", "Required attributions:", ""]
    lines += [f"- {s['attribution']}" for s in manifest["sources"] if s.get("attributionRequired")]
    lines += ["", "## Open-source software", "", "| Library | By | License |", "|---|---|---|"]
    for s in manifest["software"]:
        lines.append(f"| [{s['name']}]({s['url']}) | {s['author']} | {s['license']} |")
    lines += [
        "",
        "The full license texts of every library are bundled in the app "
        "(Profile → Credits & licenses → All open-source licenses).",
        "",
        "The machine-readable list is `assets/credits/asset_manifest.json`; "
        "regenerate this file with `python tool/build_credits.py`.",
        "",
    ]
    with open(os.path.join(ROOT, "CREDITS.md"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
    print("wrote CREDITS.md")


if __name__ == "__main__":
    main()
