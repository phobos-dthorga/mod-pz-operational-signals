#!/usr/bin/env python3
"""
snapshot-vanilla-items.py
Parses PZ item script files and produces a JSON + Markdown database.

Usage:
    py scripts/snapshot-vanilla-items.py [--pz-version 42.15.0]
"""

import argparse
import json
import os
import re
import sys
from datetime import date

DEFAULT_INPUT_DIR = os.path.join(
    "C:", os.sep,
    "Program Files (x86)", "Steam", "steamapps", "common",
    "ProjectZomboid", "media", "scripts", "generated", "items",
)

# Relative to this script's location (repo root / scripts/)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
DOCS_DIR = os.path.join(REPO_ROOT, "docs")


def parse_items_from_file(filepath):
    """Parse a single PZ item script file and yield item dicts."""
    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    # Find all module blocks
    # Format: module ModuleName { ... }
    module_pattern = re.compile(
        r"module\s+(\w+)\s*\{(.*?)\n\}",
        re.DOTALL,
    )

    for module_match in module_pattern.finditer(content):
        module_name = module_match.group(1)
        module_body = module_match.group(2)

        # Find all item blocks within the module
        # Format: item ItemName { properties... }
        item_pattern = re.compile(
            r"item\s+(\w+)\s*\{([^}]*)\}",
            re.DOTALL,
        )

        for item_match in item_pattern.finditer(module_body):
            item_name = item_match.group(1)
            props_text = item_match.group(2)

            item = parse_item_properties(module_name, item_name, props_text)
            yield item


def parse_item_properties(module_name, item_name, props_text):
    """Parse the property block of a single item."""
    item = {
        "fullType": f"{module_name}.{item_name}",
        "module": module_name,
        "name": item_name,
        "displayName": None,
        "displayCategory": None,
        "itemType": None,
        "weight": None,
        "conditionMax": None,
        "tags": [],
        "icon": None,
    }

    for line in props_text.splitlines():
        line = line.strip().rstrip(",")
        if not line or line.startswith("--"):
            continue

        # Split on first '=' only
        if "=" not in line:
            continue

        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().rstrip(",")

        if key == "DisplayName":
            item["displayName"] = value
        elif key == "DisplayCategory":
            item["displayCategory"] = value
        elif key == "ItemType":
            item["itemType"] = value
        elif key == "Weight":
            try:
                item["weight"] = float(value)
            except ValueError:
                item["weight"] = value
        elif key == "ConditionMax":
            try:
                item["conditionMax"] = int(value)
            except ValueError:
                item["conditionMax"] = value
        elif key == "Tags":
            item["tags"] = [t.strip() for t in value.split(";") if t.strip()]
        elif key == "Icon":
            item["icon"] = value

    return item


def collect_all_items(input_dir):
    """Recursively scan .txt files and collect all items."""
    items = []
    for root, _dirs, files in os.walk(input_dir):
        for filename in sorted(files):
            if not filename.endswith(".txt"):
                continue
            filepath = os.path.join(root, filename)
            for item in parse_items_from_file(filepath):
                items.append(item)
    items.sort(key=lambda x: x["fullType"].lower())
    return items


def write_json(items, pz_version, input_dir):
    """Write the JSON database."""
    output = {
        "metadata": {
            "pzVersion": pz_version,
            "snapshotDate": date.today().isoformat(),
            "totalItems": len(items),
            "sourceDirectory": input_dir,
            "generatedBy": "scripts/snapshot-vanilla-items.py",
        },
        "items": items,
    }

    os.makedirs(DOCS_DIR, exist_ok=True)
    out_path = os.path.join(DOCS_DIR, "vanilla-item-database.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"  JSON: {out_path} ({len(items)} items)")
    return out_path


def write_markdown(items, pz_version, input_dir):
    """Write the Markdown summary."""
    # Count by ItemType
    type_counts = {}
    for item in items:
        t = item["itemType"] or "(none)"
        type_counts[t] = type_counts.get(t, 0) + 1

    # Count by DisplayCategory
    cat_counts = {}
    for item in items:
        c = item["displayCategory"] or "(none)"
        cat_counts[c] = cat_counts.get(c, 0) + 1

    lines = []
    lines.append("# Vanilla Item Database")
    lines.append("")
    lines.append(f"- **PZ Version**: {pz_version}")
    lines.append(f"- **Snapshot Date**: {date.today().isoformat()}")
    lines.append(f"- **Total Items**: {len(items)}")
    lines.append(f"- **Source**: `{input_dir}`")
    lines.append(f"- **Generated By**: `scripts/snapshot-vanilla-items.py`")
    lines.append("")

    # Summary by ItemType
    lines.append("## Items by Type")
    lines.append("")
    lines.append("| ItemType | Count |")
    lines.append("|----------|------:|")
    for t in sorted(type_counts.keys()):
        lines.append(f"| {t} | {type_counts[t]} |")
    lines.append("")

    # Summary by DisplayCategory
    lines.append("## Items by DisplayCategory")
    lines.append("")
    lines.append("| DisplayCategory | Count |")
    lines.append("|-----------------|------:|")
    for c in sorted(cat_counts.keys()):
        lines.append(f"| {c} | {cat_counts[c]} |")
    lines.append("")

    # Full item list
    lines.append("## Full Item List")
    lines.append("")
    lines.append("| Name | FullType | Weight | ItemType |")
    lines.append("|------|----------|-------:|----------|")
    for item in items:
        weight = item["weight"] if item["weight"] is not None else ""
        itype = item["itemType"] or ""
        lines.append(f"| {item['name']} | {item['fullType']} | {weight} | {itype} |")
    lines.append("")

    os.makedirs(DOCS_DIR, exist_ok=True)
    out_path = os.path.join(DOCS_DIR, "vanilla-item-database.md")
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    print(f"  Markdown: {out_path}")
    return out_path


def main():
    parser = argparse.ArgumentParser(
        description="Snapshot vanilla PZ items into JSON + Markdown."
    )
    parser.add_argument(
        "--pz-version",
        default="42.15.x",
        help="PZ version string for metadata (default: 42.15.x)",
    )
    parser.add_argument(
        "--input-dir",
        default=DEFAULT_INPUT_DIR,
        help="Path to PZ items script directory",
    )
    args = parser.parse_args()

    input_dir = args.input_dir
    if not os.path.isdir(input_dir):
        print(f"ERROR: Input directory not found: {input_dir}", file=sys.stderr)
        sys.exit(1)

    txt_files = [f for f in os.listdir(input_dir) if f.endswith(".txt")]
    if not txt_files:
        print(f"ERROR: No .txt files found in: {input_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"Scanning {len(txt_files)} script files in: {input_dir}")
    items = collect_all_items(input_dir)
    print(f"Found {len(items)} items")

    write_json(items, args.pz_version, input_dir)
    write_markdown(items, args.pz_version, input_dir)
    print("Done.")


if __name__ == "__main__":
    main()
