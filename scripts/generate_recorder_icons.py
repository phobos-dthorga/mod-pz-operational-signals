#!/usr/bin/env python3
"""
generate_recorder_icons.py
Generates 10 Data-Recorder and new media icons for POSnet using OpenAI gpt-image-1.

Usage:
    set OPENAI_API_KEY=sk-...
    py scripts/generate_recorder_icons.py

    # Generate only missing icons:
    py scripts/generate_recorder_icons.py --skip-existing

    # Generate a single item:
    py scripts/generate_recorder_icons.py --items DataRecorder

    # Dry run (list items, don't generate):
    py scripts/generate_recorder_icons.py --dry-run

Icons are saved to: common/media/textures/Item_POS_<ItemName>.png
Style: 128x128 RGBA PNG, isometric pixel art, transparent background.
Estimated cost: 10 icons x ~$0.18 = ~$1.80
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

# ─── Configuration ─────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent
TEXTURE_DIR = REPO_ROOT / "common" / "media" / "textures"
IMAGE_SIZE = "1024x1024"  # gpt-image-1 generates at this size; we resize to 128x128

# Base style prompt applied to all icons
STYLE_PREFIX = (
    "A single item icon for a 2D top-down survival video game inventory. "
    "Isometric pixel-art style, 128x128 pixels, transparent background. "
    "Clean dark outlines, soft shading, item centered in frame with small padding. "
    "No text, no labels, no UI elements. Consistent with Project Zomboid art style. "
    "Muted post-apocalyptic colour palette with earthy, desaturated tones. "
    "Early 1990s technology aesthetic — no modern sleek designs. "
)

# ─── Item Definitions ──────────────────────────────────────────────────────
# Each tuple: (filename_stem, description_for_prompt)
ITEMS = [
    ("DataRecorder",
     "A ruggedized portable data logger from the early 1990s, about the size of "
     "a thick pager or small walkie-talkie. Olive drab and dark grey plastic body "
     "with a small monochrome LCD counter display showing numbers, a few physical "
     "buttons, a media insertion slot on one side, and a belt clip on the back. "
     "Small red LED indicator light. Short rubber antenna stub on top. Industrial "
     "military-grade equipment feel, like a Psion Organiser or early GPS unit. "
     "Slightly scuffed and weathered from field use."),

    ("ReconPhotograph",
     "A single Polaroid-style instant photograph, slightly curled at the edges. "
     "The photo shows a blurry, overexposed image of a building facade — barely "
     "recognisable. White border frame typical of instant photos. The image area "
     "has muted, washed-out colours suggesting a hasty surveillance snapshot. "
     "One corner is slightly dog-eared."),

    ("Microcassette",
     "A tiny microcassette tape, much smaller than a standard cassette — about the "
     "size of a matchbox. Clear plastic housing with two small tape reels visible "
     "through the window, tape appears blank/unused. Warm light grey plastic body "
     "with a tiny metal write-protect tab. Resembles a Sanyo or Olympus dictaphone "
     "tape from the 1980s-90s. Clean, new condition."),

    ("RecordedMicrocassette",
     "A microcassette tape identical in form to a blank one but clearly used. "
     "The tape window shows darkened, partially wound tape. A small adhesive label "
     "sticker has been applied with handwritten text (illegible at this size). "
     "Slightly darker overall appearance than the blank version. The tiny reels "
     "show tape wound unevenly."),

    ("RewoundMicrocassette",
     "A microcassette tape that has been manually rewound — showing slight wear. "
     "The plastic edges are a bit scuffed, and there's a small pencil graphite "
     "mark near one of the spoolholes where a pencil was used to manually rewind. "
     "The label has been written on and partially erased. Tape visible through "
     "window is wound back to the start but not perfectly even."),

    ("SpentMicrocassette",
     "A worn-out, spent microcassette tape that can no longer record. Cracked "
     "translucent shell showing crinkled and slack magnetic tape inside. One side "
     "of the housing is slightly warped. The metal write-protect tab is broken off. "
     "Overall appearance of a cassette that has been used far beyond its lifespan. "
     "Faded grey colour, visible stress marks in the plastic."),

    ("BlankFloppyDisk",
     "A 3.5-inch floppy disk in good condition. Dark blue or black plastic shell "
     "with a silver metal sliding cover protecting the magnetic disk. A blank white "
     "label area at the top. The disk has a small notch for write protection and "
     "the characteristic rounded rectangular shape of a standard 1.44MB floppy. "
     "Clean, new-old-stock appearance, like finding one still in shrink wrap."),

    ("RecordedFloppyDisk",
     "A 3.5-inch floppy disk with data recorded on it. Same form factor as a blank "
     "floppy but with a handwritten label — messy ballpoint pen text scrawled on the "
     "white label area. The metal slider shows slight wear from being inserted into "
     "drives. Overall good condition but clearly handled and used."),

    ("WornFloppyDisk",
     "A 3.5-inch floppy disk showing significant wear. The plastic shell has one "
     "corner slightly bent, the surface is scratched and scuffed. The label is "
     "partially peeled and faded. The metal slider still moves but is tarnished. "
     "The colour has faded from exposure — what was once a crisp blue/black is now "
     "a washed-out grey-blue. Still intact but clearly degraded."),

    ("CorruptFloppyDisk",
     "A severely damaged 3.5-inch floppy disk. The plastic shell is cracked open, "
     "exposing the thin circular magnetic disk inside — a dark brown mylar circle "
     "with visible scratches across its surface. The metal slider is missing or bent "
     "at an angle. The label is torn. This disk is clearly beyond saving — only "
     "useful for scrap materials. Post-apocalyptic junk quality."),
]


def resize_to_128(input_path: Path):
    """Resize a generated image down to 128x128 RGBA PNG."""
    try:
        from PIL import Image
        img = Image.open(input_path).convert("RGBA")
        img = img.resize((128, 128), Image.LANCZOS)
        img.save(input_path, "PNG")
        return True
    except ImportError:
        print("  WARNING: Pillow not installed — image saved at original size. Install with: pip install Pillow")
        return False


def generate_icon(client, item_name: str, description: str, output_path: Path) -> bool:
    """Generate a single icon via OpenAI gpt-image-1 and save to output_path."""
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

        # gpt-image-1 returns base64 data
        image_data = base64.b64decode(result.data[0].b64_json)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_bytes(image_data)

        # Resize to 128x128
        resize_to_128(output_path)

        return True

    except Exception as e:
        print(f"  ERROR generating {item_name}: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Generate POSnet Data-Recorder icons via OpenAI gpt-image-1")
    parser.add_argument("--skip-existing", action="store_true", help="Skip items that already have icons")
    parser.add_argument("--dry-run", action="store_true", help="List items without generating")
    parser.add_argument("--items", nargs="*", help="Generate only these items (by stem name)")
    args = parser.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key and not args.dry_run:
        # Try reading from Windows registry
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

    # Filter items if requested
    items = ITEMS
    if args.items:
        name_set = set(args.items)
        items = [(n, d) for n, d in ITEMS if n in name_set]
        if not items:
            print(f"No matching items found. Available: {[n for n, _ in ITEMS]}")
            sys.exit(1)

    print(f"POSnet Data-Recorder Icon Generator")
    print(f"  Output: {TEXTURE_DIR}")
    print(f"  Items:  {len(items)}")
    print(f"  Est. cost: ~${len(items) * 0.18:.2f}")
    print()

    if args.dry_run:
        for i, (name, desc) in enumerate(items, 1):
            path = TEXTURE_DIR / f"Item_POS_{name}.png"
            exists = "EXISTS" if path.exists() else "MISSING"
            print(f"  {i:2d}. Item_POS_{name}.png [{exists}]")
        return

    client = OpenAI(api_key=api_key)
    generated = 0
    skipped = 0
    failed = 0

    for i, (name, desc) in enumerate(items, 1):
        path = TEXTURE_DIR / f"Item_POS_{name}.png"

        if args.skip_existing and path.exists():
            print(f"  [{i}/{len(items)}] SKIP Item_POS_{name}.png (exists)")
            skipped += 1
            continue

        print(f"  [{i}/{len(items)}] Generating Item_POS_{name}.png ...", end=" ", flush=True)
        if generate_icon(client, name, desc, path):
            size_kb = path.stat().st_size / 1024
            print(f"OK ({size_kb:.1f} KB)")
            generated += 1
        else:
            print("FAILED")
            failed += 1

        # Rate limit safety
        if i < len(items):
            time.sleep(2)

    print()
    print(f"Done: {generated} generated, {skipped} skipped, {failed} failed")
    if generated > 0:
        print(f"Estimated cost: ~${generated * 0.18:.2f}")


if __name__ == "__main__":
    main()
