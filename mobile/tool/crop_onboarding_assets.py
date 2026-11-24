"""One-time asset prep: crop onboarding header illustrations out of the
docs/UI_Design reference PNGs. Run from the repo root:
    python3 mobile/tool/crop_onboarding_assets.py
Crop boxes were measured against the reference PNGs (each 768x1376) and
verified visually — see docs/superpowers/specs/2026-08-30-onboarding-flow-redesign-design.md.
"""
from PIL import Image

CROPS = {
    "product_selection_header.png": (
        "docs/UI_Design/user on boarding 4.png", (68, 60, 698, 427)),
    "cigarette_quantity_header.png": (
        "docs/UI_Design/after on boarding if ciagrettes selected this will open 4a.png",
        (49, 97, 367, 410)),
    "goal_selection_header.png": (
        "docs/UI_Design/after on boarding if ciagrettes selected this will open 4a.png",
        (401, 150, 719, 495)),
    "vape_quantity_header.png": ("docs/UI_Design/4b.png", (96, 100, 671, 460)),
    "pouches_quantity_header.png": ("docs/UI_Design/4c.png", (72, 122, 695, 474)),
    "hookah_quantity_header.png": ("docs/UI_Design/4d.png", (63, 68, 704, 491)),
}

OUT_DIR = "mobile/assets/images/onboarding"

if __name__ == "__main__":
    import os
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, (src, box) in CROPS.items():
        im = Image.open(src).convert("RGB")
        crop = im.crop(box)
        out_path = os.path.join(OUT_DIR, name)
        crop.save(out_path)
        print(f"{name}: {crop.size} -> {out_path}")
