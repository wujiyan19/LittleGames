"""Prepare the approved game-box artwork for app and system icon resources.

Only resamples the selected artwork for platform resource sizes; no creative edits.
Launcher artwork stays full bleed; the starting icon uses the approved transparent corners.
The native system starting window handles placement and scaling.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/art/brand-game-box/game-box-source.png'
START_SOURCE = ROOT / 'docs/art/brand-game-box/game-box-rounded-source.png'
MEDIA = ROOT / 'AppScope/resources/base/media'


if __name__ == '__main__':
    for name, artwork, size in [('app_icon.png', SOURCE, 1024), ('brand_start_icon.png', START_SOURCE, 256)]:
        with Image.open(artwork) as source:
            destination = MEDIA / name
            source.resize((size, size), Image.Resampling.LANCZOS).save(destination, optimize=True)
            print(destination.relative_to(ROOT))
