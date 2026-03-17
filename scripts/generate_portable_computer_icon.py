#!/usr/bin/env python3
"""
generate_portable_computer_icon.py
Generate the inventory icon for the POSnet Portable Computer item.

Usage:
    set OPENAI_API_KEY=sk-...
    py scripts/generate_portable_computer_icon.py

    # Skip if icon already exists:
    py scripts/generate_portable_computer_icon.py --skip-existing

    # Dry run (show prompt, don't generate):
    py scripts/generate_portable_computer_icon.py --dry-run

Icon is saved to: common/media/textures/Item_POS_PortableComputer.png
Style: 128x128 RGBA PNG, isometric pixel art, transparent background.
"""

import os
import sys
import argparse
import base64
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

# Base style prompt — matches PCP art style guidelines
STYLE_PREFIX = (
    "A single item icon for a 2D top-down survival video game inventory. "
    "Isometric pixel-art style, 128x128 pixels, transparent background. "
    "Clean dark outlines, soft shading, item centered in frame with small padding. "
    "No text, no labels, no UI elements. Consistent with Project Zomboid art style. "
)

# ─── Item Definition ──────────────────────────────────────────────────────
ITEM_NAME = "PortableComputer"
ITEM_DESCRIPTION = (
    "A chunky early-1990s portable computer in a thick beige/cream plastic "
    "housing. Clamshell luggable form factor — open, showing a small amber or "
    "green-tinted monochrome LCD screen with a dark display. Integrated keyboard "
    "below the screen with small square keys. Built-in carrying handle on top of "
    "the lid. Thick bezels around the screen area. Bulky, boxy profile — NOT a "
    "modern thin laptop. This is a heavy, brick-like portable computer from the "
    "late 1980s / early 1990s era. Worn, slightly yellowed beige plastic with "
    "subtle scuff marks and age discolouration. A few small indicator LEDs on "
    "the front edge. Chunky pixel-art with dark outlines."
)


def resize_to_128(input_path: Path):
    """Resize a generated image down to 128x128 RGBA PNG."""
    try:
        from PIL import Image
        img = Image.open(input_path).convert("RGBA")
        img = img.resize((128, 128), Image.LANCZOS)
        img.save(input_path, "PNG")
        return True
    except ImportError:
        print("  WARNING: Pillow not installed — image saved at original size. "
              "Install with: pip install Pillow")
        return False


def generate_icon(client, output_path: Path) -> bool:
    """Generate the icon via OpenAI gpt-image-1 and save to output_path."""
    prompt = STYLE_PREFIX + ITEM_DESCRIPTION

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
        print(f"  ERROR generating icon: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Generate the POSnet Portable Computer inventory icon"
    )
    parser.add_argument("--skip-existing", action="store_true",
                        help="Skip if icon already exists")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show prompt without generating")
    args = parser.parse_args()

    output_path = TEXTURE_DIR / f"Item_POS_{ITEM_NAME}.png"

    print("POSnet Portable Computer Icon")
    print(f"  Output: {output_path}")
    print()

    if args.dry_run:
        exists = "EXISTS" if output_path.exists() else "MISSING"
        print(f"  Item_POS_{ITEM_NAME}.png [{exists}]")
        print()
        print("  Prompt:")
        print(f"  {STYLE_PREFIX}{ITEM_DESCRIPTION}")
        return

    if args.skip_existing and output_path.exists():
        print(f"  SKIP (already exists)")
        return

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        # Try reading from Windows registry (Git Bash workaround)
        try:
            import winreg
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Environment")
            api_key, _ = winreg.QueryValueEx(key, "OPENAI_API_KEY")
            winreg.CloseKey(key)
        except Exception:
            pass

    if not api_key:
        print("ERROR: OPENAI_API_KEY environment variable not set.")
        print("  set OPENAI_API_KEY=sk-...")
        sys.exit(1)

    client = OpenAI(api_key=api_key)

    print(f"  Generating {ITEM_NAME}...", end=" ", flush=True)

    if generate_icon(client, output_path):
        print(f"OK -> {output_path.name}")
    else:
        print("FAILED")
        sys.exit(1)

    print()
    print("Done.")


if __name__ == "__main__":
    main()
