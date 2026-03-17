#!/usr/bin/env python3
"""
generate_terminal_bezel.py
Generates an early-90s CRT monitor bezel texture for the POSnet terminal UI.

Two-stage pipeline:
  1. OpenAI gpt-image-1.5 generates CRT monitor at 1024x1024
  2. Replicate RMBG-2.0 removes background, composited onto pure black

Then upscales to 2048x2048 via Pillow LANCZOS for 4K display support.

The monitor's screen area is pure black — POSnet's green terminal text renders
on top of this texture in-game.

Usage:
    py scripts/generate_terminal_bezel.py
    py scripts/generate_terminal_bezel.py --dry-run       # Show prompt only
    py scripts/generate_terminal_bezel.py --no-upscale     # Keep at 1024x1024
    py scripts/generate_terminal_bezel.py --skip-rembg     # Skip RMBG-2.0
    py scripts/generate_terminal_bezel.py --measure        # Show screen area overlay
    py scripts/generate_terminal_bezel.py --from-raw       # Reprocess existing raw

Output: common/media/textures/POSnet_CRT_Bezel.png (2048x2048 RGBA PNG)
Cost: ~$0.13 (OpenAI) + ~$0.01 (Replicate RMBG-2.0) per generation
"""

import argparse
import base64
import io
import json
import os
import sys
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("ERROR: Pillow not found. Install with: pip install Pillow")
    sys.exit(1)

try:
    from openai import OpenAI
except ImportError:
    OpenAI = None

# ─── Configuration ─────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent
TEXTURE_DIR = REPO_ROOT / "common" / "media" / "textures"
RAW_OUTPUT_DIR = REPO_ROOT / "scripts" / "bezel_output"

MODEL = "gpt-image-1.5"
IMAGE_SIZE = "1024x1024"
UPSCALE_SIZE = (2048, 2048)

REPLICATE_API = "https://api.replicate.com/v1"
RMBG_MODEL = "bria/remove-background"

# Screen area inset percentages (matching POS_TerminalUI.lua BEZEL constants)
SCREEN_INSETS = {
    "left": 0.15,
    "right": 0.15,
    "top": 0.13,
    "bottom": 0.30,
}

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


# ─── API Key Helpers ───────────────────────────────────────────────────────

def get_registry_value(name: str) -> str | None:
    """Read a user environment variable from Windows registry."""
    try:
        import winreg
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Environment")
        value, _ = winreg.QueryValueEx(key, name)
        winreg.CloseKey(key)
        return value if value else None
    except Exception:
        return None


def get_openai_key() -> str | None:
    """Get OpenAI API key from environment, with Windows registry fallback."""
    return os.environ.get("OPENAI_API_KEY") or get_registry_value("OPENAI_API_KEY")


def get_replicate_token() -> str | None:
    """Get Replicate API token from environment, with Windows registry fallback."""
    return (os.environ.get("REPLICATE_API_TOKEN")
            or get_registry_value("REPLICATE_API_TOKEN"))


# ─── Replicate API ─────────────────────────────────────────────────────────

def replicate_api_call(endpoint: str, token: str, body: dict | None = None,
                       method: str = "GET", retries: int = 3) -> dict:
    """Make a Replicate API request and return JSON response."""
    url = (f"{REPLICATE_API}/{endpoint}"
           if not endpoint.startswith("http") else endpoint)
    data = json.dumps(body).encode() if body else None
    for attempt in range(retries):
        req = Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("Content-Type", "application/json")
        req.add_header("Prefer", "wait")
        try:
            with urlopen(req, timeout=300) as resp:
                return json.loads(resp.read())
        except HTTPError as e:
            if e.code == 429 and attempt < retries - 1:
                wait = 5 * (attempt + 1)
                print(f"    Rate limited, waiting {wait}s...")
                time.sleep(wait)
            else:
                raise
    return {}


def run_replicate_model(model: str, input_data: dict, token: str) -> str:
    """Run a Replicate model and return the output URL."""
    body = {"input": input_data}
    result = replicate_api_call(
        f"models/{model}/predictions", token, body, "POST")

    # Poll for completion if not using sync/wait
    while result.get("status") in ("starting", "processing"):
        time.sleep(2)
        result = replicate_api_call(result["urls"]["get"], token)
        print(f"    Status: {result['status']}...")

    if result.get("status") == "failed":
        print(f"    ERROR: {result.get('error', 'Unknown error')}")
        return ""

    output = result.get("output")
    if isinstance(output, list):
        return output[0] if output else ""
    return output or ""


def image_to_data_uri(img: Image.Image) -> str:
    """Convert a PIL Image to a data URI for Replicate API input."""
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    return f"data:image/png;base64,{b64}"


def download_image(url: str) -> Image.Image:
    """Download an image from a URL and return as PIL Image."""
    with urlopen(url, timeout=60) as resp:
        data = resp.read()
    return Image.open(io.BytesIO(data)).convert("RGBA")


# ─── Image Processing ─────────────────────────────────────────────────────

def remove_background(token: str, img: Image.Image) -> Image.Image:
    """Remove background from an image using RMBG-2.0 on Replicate."""
    print("  Removing background via RMBG-2.0...", end=" ", flush=True)
    data_uri = image_to_data_uri(img)

    output_url = run_replicate_model(RMBG_MODEL, {
        "image": data_uri,
    }, token)

    if not output_url:
        print("FAILED (no output URL)")
        return img

    result = download_image(output_url)
    bbox = result.getbbox()
    if bbox is None:
        print("FAILED (blank output)")
        return img

    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    print(f"OK ({result.size[0]}x{result.size[1]}, content: {w}x{h})")
    return result


def composite_on_black(img: Image.Image) -> Image.Image:
    """Composite a transparent-background image onto a pure black canvas."""
    canvas = Image.new("RGBA", img.size, (0, 0, 0, 255))
    canvas.paste(img, (0, 0), img)
    return canvas


def fill_screen_black(img: Image.Image, insets: dict) -> Image.Image:
    """Paint a solid black rectangle over the screen area to ensure purity."""
    w, h = img.size
    left = int(w * insets["left"])
    top = int(h * insets["top"])
    right = w - int(w * insets["right"])
    bottom = h - int(h * insets["bottom"])

    # Shrink inward by 2% to avoid painting over bezel edges
    margin_x = int(w * 0.02)
    margin_y = int(h * 0.02)
    left += margin_x
    top += margin_y
    right -= margin_x
    bottom -= margin_y

    draw = ImageDraw.Draw(img)
    draw.rectangle([left, top, right, bottom], fill=(0, 0, 0, 255))
    print(f"  Screen area painted black: ({left},{top}) to ({right},{bottom})")
    return img


def fill_background_black(input_path: Path):
    """Legacy: Replace light background using luminance threshold.
    Used as fallback when --skip-rembg is specified.
    """
    img = Image.open(input_path).convert("RGBA")
    pixels = img.load()
    w, h = img.size

    bg_sample = pixels[5, 5]
    bg_lum = (bg_sample[0] + bg_sample[1] + bg_sample[2]) / 3

    if bg_lum < 50:
        print("  Background already dark — skipping fill.")
        return

    threshold = bg_lum * 0.7
    replaced = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            lum = (r + g + b) / 3
            if lum > threshold:
                edge_dist = min(x, y, w - 1 - x, h - 1 - y)
                if edge_dist < w * 0.15 or lum > bg_lum * 0.85:
                    pixels[x, y] = (0, 0, 0, 255)
                    replaced += 1

    img.save(input_path, "PNG")
    print(f"  Background fill (legacy): {replaced} pixels replaced with black.")


def upscale_image(img: Image.Image, target_size: tuple) -> Image.Image:
    """Upscale an image using Pillow LANCZOS resampling."""
    original_size = img.size
    result = img.resize(target_size, Image.LANCZOS)
    print(f"  Upscaled: {original_size[0]}x{original_size[1]} -> "
          f"{target_size[0]}x{target_size[1]}")
    return result


def measure_screen_area(img_path: Path):
    """Open the image and overlay the screen area rectangle for verification."""
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size

    left = int(w * SCREEN_INSETS["left"])
    top = int(h * SCREEN_INSETS["top"])
    right = w - int(w * SCREEN_INSETS["right"])
    bottom = h - int(h * SCREEN_INSETS["bottom"])

    # Draw a red rectangle overlay
    overlay = img.copy()
    draw = ImageDraw.Draw(overlay)
    draw.rectangle([left, top, right, bottom], outline=(255, 0, 0, 255), width=3)

    # Also fill with semi-transparent red
    red_fill = Image.new("RGBA", img.size, (0, 0, 0, 0))
    red_draw = ImageDraw.Draw(red_fill)
    red_draw.rectangle([left, top, right, bottom], fill=(255, 0, 0, 64))
    overlay = Image.alpha_composite(overlay, red_fill)

    measure_path = img_path.parent / (img_path.stem + "_measure.png")
    overlay.save(measure_path, "PNG")
    print(f"  Measurement overlay saved: {measure_path}")
    print(f"  Screen rect: ({left},{top}) to ({right},{bottom})")
    print(f"  Screen size: {right - left}x{bottom - top} "
          f"({(right - left) / w * 100:.1f}% x {(bottom - top) / h * 100:.1f}%)")


# ─── Main ──────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Generate CRT monitor bezel texture for POSnet terminal"
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Show prompt and config without generating")
    parser.add_argument("--no-upscale", action="store_true",
                        help="Skip upscaling (keep at 1024x1024)")
    parser.add_argument("--skip-rembg", action="store_true",
                        help="Skip RMBG-2.0 (use legacy luminance threshold)")
    parser.add_argument("--measure", action="store_true",
                        help="Show screen area overlay on existing image")
    parser.add_argument("--from-raw", action="store_true",
                        help="Reprocess existing raw image (skip generation)")
    args = parser.parse_args()

    print("POSnet CRT Bezel Generator")
    print(f"  Model:   {MODEL}")
    print(f"  Size:    {IMAGE_SIZE} -> {UPSCALE_SIZE[0]}x{UPSCALE_SIZE[1]}")
    print(f"  Output:  {TEXTURE_DIR / 'POSnet_CRT_Bezel.png'}")
    print()

    # Measure mode: just overlay screen area on existing image
    if args.measure:
        final_path = TEXTURE_DIR / "POSnet_CRT_Bezel.png"
        if final_path.exists():
            measure_screen_area(final_path)
        else:
            print("ERROR: No existing image to measure.")
        return

    if args.dry_run:
        print("Prompt:")
        print(f"  {PROMPT}")
        print()
        print("(Dry run — no image generated)")
        return

    RAW_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    raw_path = RAW_OUTPUT_DIR / "POSnet_CRT_Bezel_raw.png"

    # ── Stage 1: Generate (or load existing raw) ──
    if args.from_raw:
        if not raw_path.exists():
            print(f"ERROR: No raw image at {raw_path}")
            sys.exit(1)
        print(f"  Loading existing raw: {raw_path}")
        img = Image.open(raw_path).convert("RGBA")
    else:
        if OpenAI is None:
            print("ERROR: openai package not found. Install with: pip install openai")
            sys.exit(1)

        api_key = get_openai_key()
        if not api_key:
            print("ERROR: OPENAI_API_KEY not found in environment or registry.")
            sys.exit(1)

        client = OpenAI(api_key=api_key)

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
            print("FAILED")
            print(f"  Error: {e}")
            sys.exit(1)

        print("OK")
        image_data = base64.b64decode(result.data[0].b64_json)
        raw_path.write_bytes(image_data)
        print(f"  Raw saved: {raw_path}")
        img = Image.open(io.BytesIO(image_data)).convert("RGBA")

    # ── Stage 2: Background removal ──
    if args.skip_rembg:
        print("  Skipping RMBG-2.0 (using legacy luminance threshold)...")
        processed_path = RAW_OUTPUT_DIR / "POSnet_CRT_Bezel_processed.png"
        img.save(processed_path, "PNG")
        fill_background_black(processed_path)
        img = Image.open(processed_path).convert("RGBA")
    else:
        replicate_token = get_replicate_token()
        if not replicate_token:
            print("WARNING: REPLICATE_API_TOKEN not found — falling back to "
                  "legacy luminance threshold.")
            processed_path = RAW_OUTPUT_DIR / "POSnet_CRT_Bezel_processed.png"
            img.save(processed_path, "PNG")
            fill_background_black(processed_path)
            img = Image.open(processed_path).convert("RGBA")
        else:
            # AI background removal
            transparent = remove_background(replicate_token, img)
            # Save transparent version for inspection
            transparent_path = (RAW_OUTPUT_DIR
                                / "POSnet_CRT_Bezel_transparent.png")
            transparent.save(transparent_path, "PNG")
            print(f"  Transparent saved: {transparent_path}")
            # Composite onto black
            img = composite_on_black(transparent)
            print("  Composited onto black background.")

    # ── Stage 3: Clean screen area ──
    img = fill_screen_black(img, SCREEN_INSETS)

    # Save processed intermediate
    processed_path = RAW_OUTPUT_DIR / "POSnet_CRT_Bezel_final_1024.png"
    img.save(processed_path, "PNG")
    print(f"  Processed saved: {processed_path}")

    # ── Stage 4: Upscale and save ──
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    final_path = TEXTURE_DIR / "POSnet_CRT_Bezel.png"

    if args.no_upscale:
        img.save(final_path, "PNG")
        print(f"  Final saved (no upscale): {final_path}")
    else:
        img = upscale_image(img, UPSCALE_SIZE)
        img.save(final_path, "PNG")
        print(f"  Final saved: {final_path}")

    print()
    print("Done! Next steps:")
    print("  1. Run with --measure to verify screen area alignment")
    print("  2. Adjust SCREEN_INSETS in this script + BEZEL in POS_TerminalUI.lua")
    print(f"     Current: {SCREEN_INSETS}")


if __name__ == "__main__":
    main()
