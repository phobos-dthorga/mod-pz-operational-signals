#!/usr/bin/env python3
"""
generate_terminal_bezel.py
Generates an early-90s CRT monitor bezel texture for the POSnet terminal UI.

Uses OpenAI gpt-image-1.5 to generate a photorealistic CRT monitor frame at
1024x1024, then upscales to 2048x2048 via Pillow LANCZOS for 4K display support.

The monitor's screen area is pure black — POSnet's green terminal text renders
on top of this texture in-game.

Usage:
    set OPENAI_API_KEY=sk-...
    py scripts/generate_terminal_bezel.py

    # Dry run (show prompt, don't generate):
    py scripts/generate_terminal_bezel.py --dry-run

    # Skip upscale (keep at 1024x1024):
    py scripts/generate_terminal_bezel.py --no-upscale

Output: common/media/textures/POSnet_CRT_Bezel.png (2048x2048 RGBA PNG)
Cost: ~$0.13 per generation (gpt-image-1.5 high quality 1024x1024)
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
RAW_OUTPUT_DIR = REPO_ROOT / "scripts" / "bezel_output"

MODEL = "gpt-image-1.5"
IMAGE_SIZE = "1024x1024"
UPSCALE_SIZE = (2048, 2048)

PROMPT = (
    "A front-facing view of an early 1990s CRT computer monitor, perfectly "
    "centered and symmetrical. The monitor has a chunky dark grey plastic "
    "housing/bezel, approximately 3 inches thick on all sides, with the "
    "bottom bezel slightly thicker. The screen opening is a rectangle with "
    "slightly rounded inner corners, filled with pure solid black (#000000). "
    "The plastic has a slightly textured matte finish with subtle moulding "
    "lines. On the bottom bezel center: a small embossed rectangular badge "
    "area. Bottom-right of bezel: a tiny circular green LED power indicator "
    "(lit). Bottom-left: 2-3 small circular adjustment knobs/buttons. The "
    "monitor housing fills the entire image with minimal margin. No stand, "
    "no cables, no background scenery. Dark grey (#3a3a3a) plastic with "
    "subtle highlight on top edge from overhead lighting. Photorealistic "
    "rendering, not pixel art. Front view only, no perspective or angle. "
    "The screen area should be approximately 70% of the total image width "
    "and 72% of total height."
)


def get_api_key():
    """Get OpenAI API key from environment, with Windows registry fallback."""
    key = os.environ.get("OPENAI_API_KEY")
    if key:
        return key

    # Windows registry fallback (user environment variable)
    try:
        import winreg
        reg_key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Environment")
        value, _ = winreg.QueryValueEx(reg_key, "OPENAI_API_KEY")
        winreg.CloseKey(reg_key)
        if value:
            return value
    except Exception:
        pass

    return None


def fill_background_black(input_path: Path):
    """Replace the light background outside the monitor housing with black.

    Samples the top-left corner pixel as the background colour, then replaces
    all pixels within a luminance threshold of that colour with pure black.
    This eliminates the light grey/white surround that gpt-image-1.5 adds.
    """
    try:
        from PIL import Image
        img = Image.open(input_path).convert("RGBA")
        pixels = img.load()
        w, h = img.size

        # Sample corner pixels to determine background colour
        bg_sample = pixels[5, 5]
        bg_lum = (bg_sample[0] + bg_sample[1] + bg_sample[2]) / 3

        # If background is already dark, skip
        if bg_lum < 50:
            print("  Background already dark — skipping fill.")
            return

        # Replace pixels similar to background with black
        # Use a generous luminance threshold to catch gradient edges
        threshold = bg_lum * 0.7
        replaced = 0
        for y in range(h):
            for x in range(w):
                r, g, b, a = pixels[x, y]
                lum = (r + g + b) / 3
                # Only replace if luminance is close to background
                # and pixel is in the outer margin area (rough bounding box)
                if lum > threshold:
                    # Check if this pixel is likely background (not part of bezel detail)
                    # by checking proximity to edges
                    edge_dist = min(x, y, w - 1 - x, h - 1 - y)
                    if edge_dist < w * 0.15 or lum > bg_lum * 0.85:
                        pixels[x, y] = (0, 0, 0, 255)
                        replaced += 1

        img.save(input_path, "PNG")
        print(f"  Background fill: {replaced} pixels replaced with black.")
    except ImportError:
        print("  WARNING: Pillow not installed — cannot fill background.")
    except Exception as e:
        print(f"  WARNING: Background fill failed: {e}")


def upscale_image(input_path: Path, output_path: Path, target_size: tuple):
    """Upscale an image using Pillow LANCZOS resampling."""
    try:
        from PIL import Image
        img = Image.open(input_path).convert("RGBA")
        original_size = img.size
        img = img.resize(target_size, Image.LANCZOS)
        img.save(output_path, "PNG")
        print(f"  Upscaled: {original_size[0]}x{original_size[1]} -> "
              f"{target_size[0]}x{target_size[1]}")
        return True
    except ImportError:
        print("  WARNING: Pillow not installed — cannot upscale.")
        print("  Install with: pip install Pillow")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Generate CRT monitor bezel texture for POSnet terminal"
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Show prompt and config without generating")
    parser.add_argument("--no-upscale", action="store_true",
                        help="Skip upscaling (keep at 1024x1024)")
    args = parser.parse_args()

    print("POSnet CRT Bezel Generator")
    print(f"  Model:   {MODEL}")
    print(f"  Size:    {IMAGE_SIZE} -> {UPSCALE_SIZE[0]}x{UPSCALE_SIZE[1]}")
    print(f"  Output:  {TEXTURE_DIR / 'POSnet_CRT_Bezel.png'}")
    print()

    if args.dry_run:
        print("Prompt:")
        print(f"  {PROMPT}")
        print()
        print("(Dry run — no image generated)")
        return

    api_key = get_api_key()
    if not api_key:
        print("ERROR: OPENAI_API_KEY not found in environment or registry.")
        print("  set OPENAI_API_KEY=sk-...")
        sys.exit(1)

    client = OpenAI(api_key=api_key)

    # Generate image
    print("  Generating CRT bezel image...", end=" ", flush=True)
    try:
        result = client.images.generate(
            model=MODEL,
            prompt=PROMPT,
            n=1,
            size=IMAGE_SIZE,
            quality="high",
        )
    except Exception as e:
        print(f"FAILED")
        print(f"  Error: {e}")
        sys.exit(1)

    print("OK")

    # Decode and save raw image
    image_data = base64.b64decode(result.data[0].b64_json)

    RAW_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    raw_path = RAW_OUTPUT_DIR / "POSnet_CRT_Bezel_raw.png"
    raw_path.write_bytes(image_data)
    print(f"  Raw saved: {raw_path}")

    # Post-process: fill light background with black
    fill_background_black(raw_path)

    # Upscale and save final texture
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    final_path = TEXTURE_DIR / "POSnet_CRT_Bezel.png"

    if args.no_upscale:
        final_path.write_bytes(image_data)
        print(f"  Final saved (no upscale): {final_path}")
    else:
        if upscale_image(raw_path, final_path, UPSCALE_SIZE):
            print(f"  Final saved: {final_path}")
        else:
            # Fallback: save at original size
            final_path.write_bytes(image_data)
            print(f"  Final saved (original size): {final_path}")

    print()
    print("Done! Next steps:")
    print("  1. Inspect the generated image")
    print("  2. Measure the black screen area boundaries (pixel coordinates)")
    print("  3. Calculate percentage insets for BEZEL constants in POS_TerminalUI.lua")
    print("     BEZEL = { left = ?, right = ?, top = ?, bottom = ? }")


if __name__ == "__main__":
    main()
