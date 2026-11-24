"""Generate Android launcher resources from the checked-in branding PNG.

Run with Python and Pillow: python tool/generate_launcher_icons.py
No image service or API credentials are needed to regenerate these sizes.
"""
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android/app/src/main/res"
SOURCE = ROOT / "assets/branding/quit_companion_logo.png"
BACKGROUND = "#F7F2E7"


def main():
    master = Image.open(SOURCE).convert("RGBA")
    # Ignore nearly transparent pixels around the generated canvas when
    # calculating padding; preserve the original artwork and its antialiasing.
    bounds = master.getchannel("A").point(lambda alpha: 255 if alpha > 32 else 0).getbbox()
    if bounds is None:
        raise ValueError("Logo has no visible artwork")
    mark = master.crop(bounds)
    for density, scale in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2,
                           "xxhdpi": 3, "xxxhdpi": 4}.items():
        folder = RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        size = round(48 * scale)
        tile = Image.new("RGBA", (size, size), BACKGROUND)
        logo = ImageOps.contain(mark, (round(size * .76), round(size * .76)),
                                Image.Resampling.LANCZOS)
        tile.alpha_composite(logo, ((size - logo.width) // 2, (size - logo.height) // 2))
        tile.convert("RGB").save(folder / "ic_launcher.png", optimize=True)

        # Android adaptive icons use a 108dp layer; keep the mark inside the
        # central 60dp to survive circular, rounded-square and squircle masks.
        adaptive_size = round(108 * scale)
        layer = Image.new("RGBA", (adaptive_size, adaptive_size))
        logo = ImageOps.contain(mark, (round(60 * scale), round(60 * scale)),
                                Image.Resampling.LANCZOS)
        layer.alpha_composite(logo, ((adaptive_size - logo.width) // 2,
                                    (adaptive_size - logo.height) // 2))
        layer.save(folder / "ic_launcher_foreground.png", optimize=True)
        monochrome = Image.new("RGBA", layer.size, "white")
        monochrome.putalpha(layer.getchannel("A"))
        monochrome.save(folder / "ic_launcher_monochrome.png", optimize=True)
        notification_size = round(24 * scale)
        notification = Image.new("RGBA", (notification_size, notification_size))
        glyph = ImageOps.contain(mark, (round(20 * scale), round(20 * scale)),
                                Image.Resampling.LANCZOS)
        white = Image.new("RGBA", glyph.size, "white")
        white.putalpha(glyph.getchannel("A"))
        notification.alpha_composite(white, ((notification_size - white.width) // 2,
                                             (notification_size - white.height) // 2))
        drawable = RES / f"drawable-{density}"
        drawable.mkdir(parents=True, exist_ok=True)
        notification.save(drawable / "ic_stat_quit_companion.png", optimize=True)
    print("Generated launcher icons for all five Android densities.")


if __name__ == "__main__":
    main()
