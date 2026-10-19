"""Build review sheets from this run's real screenshots; never mark a review passed."""
import json
import os
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
folder = root / os.environ.get('LITTLEGAMES_THREE_OUTPUT', 'docs/device-acceptance/three-settlements-2026-10-14')
report = json.loads((folder / 'progress.json').read_text(encoding='utf-8'))
out = folder / 'visual-review'
out.mkdir(exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 20)
requested = sys.argv[1:]
if '--waste' in requested:
    sheet = Image.new('RGB', (1800, 1680), '#e9edf2')
    draw = ImageDraw.Draw(sheet)
    for row, phase in enumerate(['before', 'after']):
        for col in range(5):
            img = Image.open(folder / f'solitaire-waste-{phase}-draw-{col + 1}.jpeg').convert('RGB')
            img = img.crop((0, 125, img.width, img.height))
            img.thumbnail((350, 760))
            x, y = col * 360, row * 840
            draw.text((x + 8, y + 5), f"经典纸牌 / {phase} / 翻牌{col + 1}", font=font, fill='#17212d')
            sheet.paste(img, (x, y + 42))
    file = out / 'sheet-solitaire-waste-refresh.jpeg'
    sheet.save(file, quality=92)
    print(file)
    sys.exit(0)
if '--controls' in requested:
    for game in report['games']:
        if not game.get('controlsCheck'):
            continue
        sheet = Image.new('RGB', (1080, 840), '#e9edf2')
        draw = ImageDraw.Draw(sheet)
        for col, name in enumerate(game['controlsCheck']['evidence']):
            img = Image.open(folder / name).convert('RGB')
            img = img.crop((0, 125, img.width, img.height))
            img.thumbnail((350, 760))
            draw.text((col * 360 + 8, 5), f"{game['name']} / {['补测开局', '补测结算', '补测重开'][col]}", font=font, fill='#17212d')
            sheet.paste(img, (col * 360, 42))
        file = out / ('sheet-controls-' + game['id'] + '.jpeg')
        sheet.save(file, quality=92)
        print(file)
    sys.exit(0)
games = [g for g in report['games'] if g['rounds'] and (not requested or g['id'] in requested)]
for offset in range(0, len(games), 2):
    group = games[offset:offset+2]
    sheet = Image.new('RGB', (1800, 840 * len(group)), '#e9edf2')
    draw = ImageDraw.Draw(sheet)
    for row, game in enumerate(group):
        files = [f"{game['id']}-icon.jpeg", f"{game['id']}-r1-start.jpeg"]
        files += [r['evidence'][1] for r in game['rounds'][:3]]
        for col, name in enumerate(files):
            img = Image.open(folder / name).convert('RGB')
            # Status bar can contain private notifications and is not app UI.
            img = img.crop((0, 125, img.width, img.height))
            img.thumbnail((350, 760))
            x, y = col * 360, row * 840
            draw.text((x + 8, y + 5), f"{game['name']} / {['图标', '开局', '结算1', '结算2', '结算3'][col]}", font=font, fill='#17212d')
            sheet.paste(img, (x, y + 42))
    file = out / ('sheet-' + '-'.join(g['id'] for g in group) + '.jpeg')
    sheet.save(file, quality=92)
    print(file)
