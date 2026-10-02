"""Prepare the approved game-box artwork for app and system icon resources.

Only resamples the selected artwork for platform resource sizes; no creative edits.
The native system starting window handles placement and scaling.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/art/brand-game-box/game-box-source.png'
MEDIA = ROOT / 'AppScope/resources/base/media'


if __name__ == '__main__':
    with Image.open(SOURCE) as source:
        for name, size in [('app_icon.png', 1024), ('brand_start_icon.png', 256)]:
            destination = MEDIA / name
            source.resize((size, size), Image.Resampling.LANCZOS).save(destination, optimize=True)
            print(destination.relative_to(ROOT))
