"""Compose unchanged phone screenshots for visual review; originals remain alongside."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFont

directory = Path(sys.argv[1])
theme = sys.argv[2] if len(sys.argv) > 2 else 'light'
games = [('screwout', '拆螺丝'), ('parkingjam', '停车场挪车'),
         ('jumpjump', '跳一跳'), ('rollingball', '滚动球闯关')]
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 21)
title_font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 28)
canvas = Image.new('RGB', (1360, 800), '#E9EEF1' if theme == 'light' else '#172632')
draw = ImageDraw.Draw(canvas)
ink = '#304854' if theme == 'light' else '#E5ECEC'
draw.text((24, 15), '统一玩具风格 · 四款真机画面', font=title_font, fill=ink)
for index, (game_id, name) in enumerate(games):
    image = Image.open(directory / f'{theme}-{game_id}-ready.jpeg').convert('RGB')
    # Remove OS status/gesture bars only; do not retouch game content.
    image = image.crop((0, 125, image.width, image.height - 125))
    image.thumbnail((316, 690), Image.Resampling.LANCZOS)
    x = 24 + index * 334
    draw.text((x, 61), name, font=font, fill=ink)
    canvas.paste(image, (x, 99))
output = directory / f'overview-{theme}.png'
canvas.save(output)
print(output.resolve())
