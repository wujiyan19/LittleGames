import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding='utf-8')
root = Path(__file__).resolve().parents[1]
progress = json.loads((root / 'docs/device-acceptance/mate60-fix-progress.json').read_text(encoding='utf-8'))
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 21)
out = root / 'docs/device-acceptance/visual-review'
out.mkdir(exist_ok=True)
modes = (sys.argv[1],) if len(sys.argv) > 1 else ('light', 'dark')
assert all(mode in ('light', 'dark') for mode in modes)
for mode in modes:
    items = progress['smoke'][mode]
    if '--partial' in sys.argv[2:]:
        items = items if len(items) == 33 else items[:len(items) // 6 * 6]
    else:
        assert len(items) == 33, f'{mode} checks are not complete'
    for start in range(0, len(items), 6):
        sheet = Image.new('RGB', (1260, 1894), (235, 235, 235))
        draw = ImageDraw.Draw(sheet)
        for i, item in enumerate(items[start:start + 6]):
            screenshot = root / 'docs/screenshots' / (item['evidence'] + '.jpeg')
            image = Image.open(screenshot).convert('RGB')
            image.thumbnail((420, 907))
            x, y = (i % 3) * 420, (i // 3) * 947
            draw.text((x + 12, y + 5), f"{start + i + 1}. {item['name']}", font=font, fill=(0, 0, 0))
            sheet.paste(image, (x, y + 35))
        file = out / f'fix-{mode}-{start // 6 + 1}.jpeg'
        sheet.save(file, quality=94)
        print(file)
