#!/usr/bin/env python3
"""
snapshot-room-categories.py
Parses PZ's Distributions.lua to extract room names and auto-map them
to commodity categories for the POSnet market system.

Usage:
    py scripts/snapshot-room-categories.py [--pz-version 42.15.0]
"""

import argparse
import json
import os
import re
import sys
from datetime import date

DEFAULT_INPUT_FILE = os.path.join(
    "C:", os.sep,
    "Program Files (x86)", "Steam", "steamapps", "common",
    "ProjectZomboid", "media", "lua", "server", "Items", "Distributions.lua",
)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
DOCS_DIR = os.path.join(REPO_ROOT, "docs")

# ---------------------------------------------------------------
# Keyword patterns: checked in order, first match wins.
# IMPORTANT: Keep in sync with POS_RoomCategoryMap.lua PATTERNS table.
# ---------------------------------------------------------------
CATEGORY_PATTERNS = [
    # Fuel
    ("gas", "fuel"),
    ("fuel", "fuel"),
    ("garage", "fuel"),
    ("mechanic", "fuel"),
    ("fossoil", "fuel"),

    # Medicine
    ("pharmacy", "medicine"),
    ("medical", "medicine"),
    ("clinic", "medicine"),
    ("hospital", "medicine"),
    ("doctor", "medicine"),
    ("dentist", "medicine"),
    ("vet", "medicine"),
    ("morgue", "medicine"),
    ("coroner", "medicine"),

    # Food
    ("grocery", "food"),
    ("kitchen", "food"),
    ("restaurant", "food"),
    ("bakery", "food"),
    ("butcher", "food"),
    ("cafe", "food"),
    ("cafeteria", "food"),
    ("diner", "food"),
    ("bar", "food"),
    ("pizz", "food"),
    ("spiffo", "food"),
    ("jayschicken", "food"),
    ("gigamart", "food"),
    ("burger", "food"),
    ("donut", "food"),
    ("icecream", "food"),
    ("sushi", "food"),
    ("catfish", "food"),
    ("chinese", "food"),
    ("italian", "food"),
    ("mexican", "food"),
    ("western", "food"),
    ("deepfry", "food"),
    ("fishchip", "food"),
    ("hotdog", "food"),
    ("candy", "food"),
    ("brewery", "food"),
    ("whiskey", "food"),
    ("liquor", "food"),
    ("dining", "food"),
    ("produce", "food"),
    ("jerky", "food"),
    ("crepe", "food"),
    ("juice", "food"),
    ("egg", "food"),
    ("corner", "food"),
    ("convenience", "food"),

    # Ammunition
    ("gun", "ammunition"),
    ("armory", "ammunition"),
    ("army", "ammunition"),
    ("military", "ammunition"),
    ("police", "ammunition"),
    ("hunting", "ammunition"),
    ("swat", "ammunition"),
    ("prison", "ammunition"),
    ("ammo", "ammunition"),

    # Tools
    ("warehouse", "tools"),
    ("tool", "tools"),
    ("hardware", "tools"),
    ("construct", "tools"),
    ("plumb", "tools"),
    ("carpent", "tools"),
    ("welding", "tools"),
    ("factory", "tools"),
    ("shipping", "tools"),
    ("logging", "tools"),
    ("railroad", "tools"),
    ("metalfab", "tools"),
    ("metalshop", "tools"),

    # Radio / Electronics
    ("electronic", "radio"),
    ("office", "radio"),
    ("computer", "radio"),
    ("radio", "radio"),
    ("cyber", "radio"),

    # Chemicals (PCP cross-mod)
    ("lab", "chemicals"),
    ("chem", "chemicals"),
    ("drug", "chemicals"),
]


def extract_room_names(filepath):
    """Extract top-level room name keys from distributionTable in Distributions.lua."""
    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    # Match top-level keys: lines starting with tab or spaces followed by a word and ' = {'
    # Both tab-indented and space-indented keys occur in the file.
    pattern = re.compile(r"^[\t ]+(\w+)\s*=\s*\{", re.MULTILINE)

    # We need only top-level keys (depth 1 inside distributionTable).
    # Strategy: track brace depth. After seeing `local distributionTable = {`,
    # every key at depth 1 is a room name.
    rooms = []
    in_table = False
    depth = 0

    for line in content.splitlines():
        if not in_table:
            if "distributionTable" in line and "=" in line and "{" in line:
                in_table = True
                depth = 1  # we just entered the table
            continue

        # Count braces on this line
        opens = line.count("{")
        closes = line.count("}")

        # Before updating depth, check if this line defines a key at depth 1
        if depth == 1:
            m = re.match(r"^[\t ]+(\w+)\s*=\s*\{", line)
            if m:
                key = m.group(1)
                # Room names are all-lowercase (with underscores).
                # PascalCase keys (e.g. AmmoStrap_Bullets, Bag_ALICEpack)
                # are container/bag loot tables, not rooms -- skip them.
                if key == key.lower():
                    rooms.append(key)

        depth += opens - closes

        if depth <= 0:
            break  # exited distributionTable

    return sorted(set(rooms))


def categorize_room(room_name):
    """Map a room name to a category using keyword patterns."""
    lower = room_name.lower()
    for keyword, category in CATEGORY_PATTERNS:
        if keyword in lower:
            return category
    return "unmapped"


def build_mappings(rooms):
    """Build category -> rooms mapping."""
    mappings = {}
    for room in rooms:
        cat = categorize_room(room)
        if cat not in mappings:
            mappings[cat] = []
        mappings[cat].append(room)

    # Sort each category's room list
    for cat in mappings:
        mappings[cat].sort()

    return mappings


def write_json(rooms, mappings, pz_version):
    """Write the JSON mapping file."""
    unmapped_count = len(mappings.get("unmapped", []))
    mapped_count = len(rooms) - unmapped_count

    output = {
        "metadata": {
            "pzVersion": pz_version,
            "snapshotDate": date.today().isoformat(),
            "totalRooms": len(rooms),
            "mappedRooms": mapped_count,
            "unmappedRooms": unmapped_count,
            "generatedBy": "scripts/snapshot-room-categories.py",
        },
        "mappings": {k: v for k, v in sorted(mappings.items())},
        "allRooms": rooms,
    }

    os.makedirs(DOCS_DIR, exist_ok=True)
    out_path = os.path.join(DOCS_DIR, "room-category-mapping.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"  JSON: {out_path}")
    return out_path


def write_markdown(rooms, mappings, pz_version):
    """Write the Markdown summary."""
    unmapped_count = len(mappings.get("unmapped", []))
    mapped_count = len(rooms) - unmapped_count

    lines = []
    lines.append("# Room Category Mapping")
    lines.append("")
    lines.append(f"- **PZ Version**: {pz_version}")
    lines.append(f"- **Snapshot Date**: {date.today().isoformat()}")
    lines.append(f"- **Total Rooms**: {len(rooms)}")
    lines.append(f"- **Mapped**: {mapped_count}")
    lines.append(f"- **Unmapped**: {unmapped_count}")
    lines.append(f"- **Generated By**: `scripts/snapshot-room-categories.py`")
    lines.append("")

    # Summary table
    lines.append("## Category Summary")
    lines.append("")
    lines.append("| Category | Count |")
    lines.append("|----------|------:|")
    for cat in sorted(mappings.keys()):
        lines.append(f"| {cat} | {len(mappings[cat])} |")
    lines.append("")

    # Per-category room lists
    lines.append("## Rooms by Category")
    lines.append("")
    for cat in sorted(mappings.keys()):
        lines.append(f"### {cat}")
        lines.append("")
        for room in mappings[cat]:
            lines.append(f"- `{room}`")
        lines.append("")

    os.makedirs(DOCS_DIR, exist_ok=True)
    out_path = os.path.join(DOCS_DIR, "room-category-mapping.md")
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    print(f"  Markdown: {out_path}")
    return out_path


def main():
    parser = argparse.ArgumentParser(
        description="Snapshot PZ room types and map to commodity categories."
    )
    parser.add_argument(
        "--pz-version",
        default="42.15.x",
        help="PZ version string for metadata (default: 42.15.x)",
    )
    parser.add_argument(
        "--input-file",
        default=DEFAULT_INPUT_FILE,
        help="Path to Distributions.lua",
    )
    args = parser.parse_args()

    input_file = args.input_file
    if not os.path.isfile(input_file):
        print(f"ERROR: Input file not found: {input_file}", file=sys.stderr)
        sys.exit(1)

    print(f"Parsing: {input_file}")
    rooms = extract_room_names(input_file)
    print(f"Found {len(rooms)} room types")

    mappings = build_mappings(rooms)

    write_json(rooms, mappings, args.pz_version)
    write_markdown(rooms, mappings, args.pz_version)

    # Print summary
    for cat in sorted(mappings.keys()):
        print(f"  {cat}: {len(mappings[cat])} rooms")

    print("Done.")


if __name__ == "__main__":
    main()
