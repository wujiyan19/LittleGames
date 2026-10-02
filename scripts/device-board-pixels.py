import json, sys
from PIL import Image
data = json.load(open(sys.argv[1], encoding='utf-8'))
image = Image.open(data['file']).convert('RGB')
out = []
for x0,y0,x1,y1 in data['bounds']:
    x,y = int((x0+x1)/2),int((y0+y1)/2)
    r,g,b = image.getpixel((x,y))
    if data['kind']=='lights': out.append(int(r+g+b>420))
    elif data['kind']=='maze':
        r,g,b=image.getpixel((int(x0+(x1-x0)*.2),int(y0+(y1-y0)*.7)))
        out.append(int(g>r+10))
    elif data['kind']=='gems':
        # Center facets measured from the rendered device image (including white highlights).
        # Using the base fill colors can confuse the red pentagon with the pink heart.
        palette=[(221,146,166),(239,189,138),(110,193,167),(117,181,227),(229,154,195),(166,156,225)]
        out.append(min(range(6),key=lambda i:sum((palette[i][j]-v)**2 for j,v in enumerate((r,g,b)))))
    elif data['kind']=='memory':
        dx,dy=(x1-x0)*.175,(y1-y0)*.20
        crop=image.crop((x0+dx,y0+dy,x1-dx,y1-dy)).resize((12,12))
        out.append([v for pixel in crop.get_flattened_data() for v in pixel])
    else: out.append([r,g,b])
print(json.dumps(out))
