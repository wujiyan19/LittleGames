import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding='utf-8')
root=Path(__file__).resolve().parents[1]
checkpoint=root/'docs/device-acceptance/mate60-public-progress.json'
items=json.loads(checkpoint.read_text(encoding='utf-8'))['darkGames']
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',21)
out=root/'docs/device-acceptance/visual-review'
out.mkdir(exist_ok=True)
for start in range(0,len(items),6):
    group=items[start:start+6]
    width,height=420,947
    sheet=Image.new('RGB',(width*3,height*2),(235,235,235))
    draw=ImageDraw.Draw(sheet)
    for index,item in enumerate(group):
        image=Image.open(root/'docs/screenshots'/f"{item['screenshot']}.jpeg").convert('RGB')
        image.thumbnail((width,907))
        x=(index%3)*width;y=(index//3)*height
        draw.text((x+12,y+5),f"{start+index+1}. {item['name']}",font=font,fill=(0,0,0))
        sheet.paste(image,(x,y+35))
    file=out/f'dark-{start//6+1}.jpeg'
    sheet.save(file,quality=94)
    print(file)
