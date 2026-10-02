import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding='utf-8')
root = Path(__file__).resolve().parents[1]
folder = root / 'docs/device-acceptance/tablet-window-2026-10-02'
progress = json.loads((folder / 'progress.json').read_text(encoding='utf-8'))
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 20)
mode = sys.argv[1]
items = progress['groups'].get(mode, [])
for start in range(0, len(items), 6):
    batch = items[start:start + 6]
    sheet = Image.new('RGB', (1500, 780), (236, 236, 236))
    draw = ImageDraw.Draw(sheet)
    for index, item in enumerate(batch):
        image = Image.open(folder / (item['evidence'] + '.jpeg')).convert('RGB')
        image.thumbnail((500, 345))
        x, y = (index % 3) * 500, (index // 3) * 390
        draw.text((x+8, y+4), item['name'], font=font, fill=(0,0,0))
        sheet.paste(image, (x+(500-image.width)//2, y+36))
    filename = folder / f'{mode}-sheet-{start//6+1}.jpeg'
    sheet.save(filename, quality=93)
    print(filename)
