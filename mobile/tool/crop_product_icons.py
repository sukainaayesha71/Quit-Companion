"""One-time asset prep: crop the four hand-drawn product icons out of the
docs/UI_Design "user on boarding 4.png" reference and cut them out as
transparent PNGs (alpha computed by distance from each icon's own locally
sampled card background — white for Vape/Pouches/Hookah, terracotta-light
for Cigarettes, since that's the only state shown selected in the
reference). Run from the repo root:
    python3 mobile/tool/crop_product_icons.py
Crop boxes were measured by connected-component detection against the
reference PNG (768x1376) and verified visually.
"""
from PIL import Image
import numpy as np
import os

SRC = "docs/UI_Design/user on boarding 4.png"
OUT_DIR = "mobile/assets/images/onboarding/icons"

BOXES = {
    "product_icon_vape.png": (199, 712, 312, 826),
    "product_icon_cigarettes.png": (454, 733, 572, 801),
    "product_icon_pouches.png": (206, 991, 304, 1064),
    "product_icon_hookah.png": (470, 968, 584, 1087),
}

LOW, HIGH = 15, 45  # color-distance-from-background alpha ramp


def extract(im, box):
    x0, y0, x1, y1 = box
    crop = np.array(im.crop(box).convert("RGB")).astype(int)
    corners = np.concatenate([
        crop[0:3, 0:3].reshape(-1, 3), crop[0:3, -3:].reshape(-1, 3),
        crop[-3:, 0:3].reshape(-1, 3), crop[-3:, -3:].reshape(-1, 3),
    ])
    bg = np.median(corners, axis=0)
    dist = np.abs(crop - bg).sum(axis=2)
    alpha = np.clip((dist - LOW) / (HIGH - LOW), 0, 1) * 255
    rgba = np.dstack([crop, alpha.astype(np.uint8)])
    return Image.fromarray(rgba.astype(np.uint8), mode="RGBA")


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    im = Image.open(SRC)
    for name, box in BOXES.items():
        icon = extract(im, box)
        out_path = os.path.join(OUT_DIR, name)
        icon.save(out_path)
        print(f"{name}: {icon.size} -> {out_path}")
