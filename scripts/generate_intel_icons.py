#!/usr/bin/env python3
"""
generate_intel_icons.py
Generates 14 icons for Camera Workstation, SIGINT Skill Books, Terminal Analysis
fragments, and Satellite Uplink UI elements using OpenAI gpt-image-1.

Usage:
    set OPENAI_API_KEY=sk-...
    py scripts/generate_intel_icons.py

    # Generate only missing icons:
    py scripts/generate_intel_icons.py --skip-existing

    # Generate a single item:
    py scripts/generate_intel_icons.py --items CompiledSiteSurvey

    # Dry run (list items, don't generate):
    py scripts/generate_intel_icons.py --dry-run

Icons are saved to: common/media/textures/
- Item icons: Item_POS_<ItemName>.png (128x128)
- UI icons: UI_POS_<Name>.png (32x32)
Estimated cost: 14 icons x ~$0.18 = ~$2.52
"""

import os
import sys
import argparse
import base64
import time
from pathlib import Path

try:
    from openai import OpenAI
except ImportError:
    print("ERROR: openai package not found. Install with: pip install openai")
    sys.exit(1)

# --- Configuration ---
REPO_ROOT = Path(__file__).resolve().parent.parent
TEXTURE_DIR = REPO_ROOT / "common" / "media" / "textures"
IMAGE_SIZE = "1024x1024"

# Base style prompt applied to all item icons (128x128)
STYLE_PREFIX = (
    "A single item icon for a 2D top-down survival video game inventory. "
    "Isometric pixel-art style, 128x128 pixels, transparent background. "
    "Clean dark outlines, soft shading, item centered in frame with small padding. "
    "No text, no labels, no UI elements. Consistent with Project Zomboid art style. "
    "Muted post-apocalyptic colour palette with earthy, desaturated tones. "
    "Early 1990s technology aesthetic — no modern sleek designs. "
)

# UI icon style prefix (32x32)
UI_STYLE_PREFIX = (
    "A tiny 32x32 pixel UI indicator icon for a survival video game HUD. "
    "Clean pixel art, transparent background, simple recognisable silhouette. "
    "Muted post-apocalyptic colour palette. No text. "
)

# --- Item Definitions ---
# Each tuple: (filename_stem, prefix, target_size, description)
ITEMS = [
    # Camera Workstation artifacts
    ("CompiledSiteSurvey", "Item_POS_", 128,
     "A clipboard with a typed document attached, held together by a metal clip. "
     "The document has neat rows of text and a small official-looking stamp or seal "
     "in the corner (red ink). Clean, professional look. The clipboard is brown "
     "pressboard with a silver metal clip at top. Paper is white with faint typed text."),

    ("VerifiedIntelReport", "Item_POS_", 128,
     "A manila file folder, slightly open, with a paper edge visible inside. "
     "A large red rubber stamp reading 'VERIFIED' is prominently visible on the "
     "folder cover at an angle. The folder is a warm buff/tan colour, slightly "
     "worn at the edges. One or two paper sheets peek out from the top. "
     "Authoritative, bureaucratic feel. Metal filing tab at the top."),

    ("MarketBulletin", "Item_POS_", 128,
     "A VHS-C tape cassette with a small typed paper summary label attached to it "
     "with a paper clip. The VHS tape is dark grey/black plastic with a visible "
     "tape window. The attached paper note has a few lines of text and looks like "
     "a broadcast-ready summary document. Professional but field-expedient feel. "
     "The label has a small header or title area."),

    # SIGINT Skill Books
    ("SIGINTBook1", "Item_POS_", 128,
     "A thin paperback book with a cover illustration of a radio tower with concentric "
     "signal waves emanating from it against a dark blue night sky. The book is "
     "slightly dog-eared and worn. Title area at top in simple sans-serif font. "
     "Looks like a hobbyist guidebook from the early 1990s. Bright but faded colours."),

    ("SIGINTBook2", "Item_POS_", 128,
     "A spiral-bound technical manual with a white cover. Simple geometric diagram "
     "of signal waveforms on the cover in blue and black ink. Looks like a college "
     "textbook or training manual. Plastic spiral binding visible on the left edge. "
     "Clean, academic appearance. Some page edges visible at bottom."),

    ("SIGINTBook3", "Item_POS_", 128,
     "A hardcover book with a dark olive/army green cover. A red 'DECLASSIFIED' stamp "
     "diagonally across the front. Cold War era aesthetic — thick, serious-looking "
     "academic text. Gold or white text on spine area. Slightly yellowed pages "
     "visible at the edge. The cover is plain except for the stamp and a simple "
     "title block. Looks like it came from a government archive."),

    ("SIGINTBook4", "Item_POS_", 128,
     "A military field manual — small, thick, pocket-sized book in olive drab green. "
     "A simple insignia or unit badge on the cover. 'FM' designation number in a "
     "header block. Rounded corners from use. Looks like a US Army Technical Manual "
     "from the 1980s. Sturdy card stock cover, matte finish. Some edge wear and "
     "a crease on the cover."),

    ("SIGINTBook5", "Item_POS_", 128,
     "A thick academic textbook with a dark navy blue hardcover. Several colourful "
     "sticky notes (post-its) protrude from the top and side edges — yellow, pink, "
     "orange tabs marking important pages. The book is heavy and scholarly-looking. "
     "A complex technical diagram or abstract pattern on the cover in silver/white. "
     "Looks like a graduate-level reference text."),

    # Terminal Analysis fragments
    ("IntelFragmentary", "Item_POS_", 128,
     "A small torn scrap of paper with a faint static-like waveform pattern printed "
     "on it in grey and dark grey. The paper is ragged-edged, clearly torn from a "
     "larger document. Noisy, incomplete data visualisation — broken lines and dots. "
     "Grey-toned, low contrast. Suggests corrupted or incomplete signal data. "
     "The paper itself is slightly crumpled."),

    ("IntelUnverified", "Item_POS_", 128,
     "A standard 3x5 index card with handwritten notes in pencil. The writing is "
     "somewhat messy and hasty — shorthand notations and numbers. The card has a "
     "warm yellow/cream tint. One corner is slightly curled. A small question mark "
     "is circled in the corner, suggesting unverified status. Lined ruled card."),

    ("IntelCorrelated", "Item_POS_", 128,
     "A piece of graph paper or chart paper with several data points connected by "
     "drawn lines, forming a pattern or network. Blue ink lines connecting nodes, "
     "with small circles at intersection points. The paper has a light blue grid. "
     "Suggests cross-referenced, correlated data. Clean, analytical appearance. "
     "A few annotations in red ink at key nodes."),

    ("IntelConfirmed", "Item_POS_", 128,
     "A crisp typed document on white paper with a prominent green checkmark stamp "
     "in the lower right corner. The text is neatly formatted in typewriter font — "
     "a verified intelligence report. Clean, authoritative, official-looking. "
     "High contrast black text on white paper. The green stamp gives confidence "
     "that this data has been verified and is trustworthy."),

    # Satellite UI indicators
    ("SatelliteLinked", "UI_POS_", 32,
     "A small satellite dish antenna pointing upward with two curved signal wave "
     "arcs emanating from it, coloured green to indicate active/linked status. "
     "Simple silhouette style. Green and dark grey."),

    ("SatelliteUnlinked", "UI_POS_", 32,
     "A small satellite dish antenna pointing upward but greyed out, with no signal "
     "waves. A small red X or slash mark indicating disconnected/unlinked status. "
     "Simple silhouette style. Grey and muted red."),
]


def resize_icon(input_path: Path, target_size: int) -> bool:
    """Resize an image to target_size x target_size using Pillow."""
    try:
        from PIL import Image
        img = Image.open(input_path).convert("RGBA")
        img = img.resize((target_size, target_size), Image.LANCZOS)
        img.save(input_path, "PNG")
        return True
    except ImportError:
        print(f"  WARNING: Pillow not installed — image saved at original size.")
        return False


def generate_icon(client, item_name: str, prefix: str, target_size: int,
                  description: str, output_path: Path) -> bool:
    """Generate a single icon via OpenAI gpt-image-1 and save to output_path."""
    if target_size <= 32:
        prompt = UI_STYLE_PREFIX + description
    else:
        prompt = STYLE_PREFIX + description

    try:
        result = client.images.generate(
            model="gpt-image-1",
            prompt=prompt,
            n=1,
            size=IMAGE_SIZE,
            quality="high",
            background="transparent",
        )

        image_data = base64.b64decode(result.data[0].b64_json)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_bytes(image_data)

        resize_icon(output_path, target_size)
        return True

    except Exception as e:
        print(f"  ERROR generating {item_name}: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Generate POSnet intelligence system icons via OpenAI gpt-image-1")
    parser.add_argument("--skip-existing", action="store_true",
                        help="Skip items that already have icons")
    parser.add_argument("--dry-run", action="store_true",
                        help="List items without generating")
    parser.add_argument("--items", nargs="*",
                        help="Generate only these items (by stem name)")
    args = parser.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key and not args.dry_run:
        try:
            import winreg
            k = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Environment")
            api_key, _ = winreg.QueryValueEx(k, "OPENAI_API_KEY")
        except Exception:
            pass

    if not api_key and not args.dry_run:
        print("ERROR: OPENAI_API_KEY environment variable not set.")
        print("  set OPENAI_API_KEY=sk-...")
        sys.exit(1)

    items = ITEMS
    if args.items:
        name_set = set(args.items)
        items = [(n, p, s, d) for n, p, s, d in ITEMS if n in name_set]
        if not items:
            print(f"No matching items found. Available: {[n for n, _, _, _ in ITEMS]}")
            sys.exit(1)

    print("POSnet Intelligence System Icon Generator")
    print(f"  Output: {TEXTURE_DIR}")
    print(f"  Items:  {len(items)}")
    print(f"  Est. cost: ~${len(items) * 0.18:.2f}")
    print()

    if args.dry_run:
        for i, (name, prefix, size, _) in enumerate(items, 1):
            path = TEXTURE_DIR / f"{prefix}{name}.png"
            exists = "EXISTS" if path.exists() else "MISSING"
            print(f"  {i:2d}. {prefix}{name}.png [{size}x{size}] [{exists}]")
        return

    client = OpenAI(api_key=api_key)
    generated = 0
    skipped = 0
    failed = 0

    for i, (name, prefix, size, desc) in enumerate(items, 1):
        path = TEXTURE_DIR / f"{prefix}{name}.png"

        if args.skip_existing and path.exists():
            print(f"  [{i}/{len(items)}] SKIP {prefix}{name}.png (exists)")
            skipped += 1
            continue

        print(f"  [{i}/{len(items)}] Generating {prefix}{name}.png [{size}x{size}] ...",
              end=" ", flush=True)
        if generate_icon(client, name, prefix, size, desc, path):
            size_kb = path.stat().st_size / 1024
            print(f"OK ({size_kb:.1f} KB)")
            generated += 1
        else:
            print("FAILED")
            failed += 1

        if i < len(items):
            time.sleep(2)

    print()
    print(f"Done: {generated} generated, {skipped} skipped, {failed} failed")
    if generated > 0:
        print(f"Estimated cost: ~${generated * 0.18:.2f}")


if __name__ == "__main__":
    main()
