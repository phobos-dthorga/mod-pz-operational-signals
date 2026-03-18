#!/usr/bin/env python3
"""
generate_recon_icons.py
Generates 11 passive recon device and VHS tape icons for POSnet using OpenAI gpt-image-1.

Usage:
    set OPENAI_API_KEY=sk-...
    py scripts/generate_recon_icons.py

    # Generate only missing icons:
    py scripts/generate_recon_icons.py --skip-existing

    # Generate a single item:
    py scripts/generate_recon_icons.py --items ReconCamcorder

    # Dry run (list items, don't generate):
    py scripts/generate_recon_icons.py --dry-run

Icons are saved to: common/media/textures/Item_POS_<ItemName>.png
Style: 128x128 RGBA PNG, isometric pixel art, transparent background.
Estimated cost: 11 icons x ~$0.18 = ~$1.98
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
    ("ReconCamcorder",
     "A compact early-1990s VHS-C camcorder. Grey and black plastic body with "
     "a flip-out viewfinder, built-in hand strap, and a small recording indicator light. "
     "Boxy consumer electronics design typical of Panasonic/JVC era. Neck strap "
     "attachment points visible. Worn but functional appearance."),

    ("FieldSurveyLogger",
     "A rugged handheld electronic data logger from the early 1990s. Dark grey "
     "plastic casing with a small green LCD screen, rubber grip sides, and a "
     "keypad with physical buttons. Industrial survey equipment style, like a "
     "Trimble or Symbol Technologies barcode scanner. Belt clip visible."),

    ("DataCalculator",
     "A scientific calculator from the early 1990s, like a Texas Instruments "
     "TI-85 or Casio fx series. Dark grey/black with a large LCD screen showing "
     "some digits, rows of small rubber buttons, and a solar panel strip at top. "
     "Compact pocket-sized device. Slightly worn edges."),

    ("BlankVHSCTape",
     "A compact VHS-C videocassette tape, brand new in appearance. Small rectangular "
     "cassette with a clear window showing blank magnetic tape on two reels. "
     "Light grey plastic shell with a clean white label area. Much smaller than "
     "a regular VHS tape — palm-sized."),

    ("RecordedReconTape",
     "A VHS-C compact cassette tape with a handwritten label reading recon data. "
     "Same small form factor as a VHS-C tape but with a slightly worn look and "
     "a piece of masking tape as a label with scribbled text. The tape window "
     "shows partially wound magnetic tape."),

    ("WornVHSTape",
     "A heavily used and degraded VHS-C compact cassette. Scuffed grey plastic "
     "shell with visible scratches, a faded and peeling label, and the tape "
     "window showing slightly slack magnetic tape. Worn out but still intact."),

    ("DamagedVHSTape",
     "A broken VHS-C compact cassette tape. Cracked plastic shell with one corner "
     "chipped, exposed magnetic tape ribbon partially pulled out of the housing. "
     "Damaged but potentially salvageable for repair. Dark grey plastic debris."),

    ("MagneticTapeScrap",
     "A small tangled bundle of loose brown/black magnetic tape ribbon, pulled "
     "from a VHS cassette. Thin shiny film material in a messy coil. Salvaged "
     "raw material for crafting makeshift tapes. Resembles unspooled cassette "
     "tape scattered on the ground."),

    ("RefurbishedVHSCTape",
     "A repaired VHS-C compact cassette tape. Grey plastic shell with visible "
     "adhesive tape patches on the casing where cracks were fixed. A functional "
     "but clearly repaired piece of equipment. Tape visible through window "
     "appears intact. Handwritten label."),

    ("SplicedReconTape",
     "A makeshift VHS-C cassette made from spliced tape segments. The cassette "
     "shell has been opened and resealed with visible adhesive strips. Through "
     "the window, the magnetic tape shows a visible splice junction — two pieces "
     "of tape joined with a small piece of adhesive. Crude but functional."),

    ("ImprovisedReconTape",
     "An extremely crude improvised videocassette. A VHS-C shell held together "
     "with duct tape, containing scavenged magnetic tape from multiple sources. "
     "Very rough appearance — mismatched plastic pieces, visible glue residue, "
     "and uneven tape tension visible through the clouded window. Desperate "
     "post-apocalyptic craft quality."),
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
    parser = argparse.ArgumentParser(description="Generate POSnet recon device icons via OpenAI gpt-image-1")
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

    print(f"POSnet Passive Recon Icon Generator")
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
