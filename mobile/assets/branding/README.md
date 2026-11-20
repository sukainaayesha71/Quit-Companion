# Quit Companion logo

`quit_companion_logo.png` is the original transparent artwork generated using
the built-in image generation tool. The sage Q/embracing hand and terracotta
leaf match the app's recovery theme; Android places them on cream `#F7F2E7`.

Android uses generated legacy launcher icons, adaptive foreground layers and
Android 13 monochrome layers. Regenerate them from `mobile/` with Python and
Pillow installed:

```powershell
python -m pip install Pillow
python tool/generate_launcher_icons.py
```

Original generation prompt:

> Use case: logo-brand. Create a polished production Android launcher foreground
> logo for Quit Companion, a nicotine quitting and recovery app. One simple bold
> rounded sage-green (#57705A) circular embracing Q-shaped symbol with a small
> upward terracotta (#C1603F) leaf, suggesting recovery, growth and companionship.
> Crisp flat vector-like silhouette, modern friendly wellness identity, strong
> negative space, readable at 48 pixels. Center entire emblem in the middle 58%
> of a square transparent canvas for adaptive Android launcher safe area. Actual
> transparent background. No words, letters as typography, mockups, shadows,
> gradients, tile background, cigarettes, medical crosses or watermark. Designed
> to sit on warm cream #F7F2E7.
