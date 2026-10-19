"""Locate the teal ball in a rendered screenshot; no model or application state."""
import json
import sys
from PIL import Image

image = Image.open(sys.argv[1]).convert('RGB')
left, top, right, bottom = json.loads(sys.argv[2])
points = []
for y in range(top + 2, bottom - 2, 2):
    for x in range(left + 2, right - 2, 2):
        red, green, blue = image.getpixel((x, y))
        if green > 100 and green > red + 18 and -8 < blue - green < 18:
            points.append((x, y))
if len(points) < 30:
    raise RuntimeError('Teal ball was not found in the rendered board')
# JPEG edge pixels on the blue/green rails may have the same hue. Select the ball's
# connected regions before measuring; its cream stripe can split it into two halves.
remaining = set(points)
regions = []
while remaining:
    seed = remaining.pop()
    region = [seed]
    pending = [seed]
    while pending:
        x, y = pending.pop()
        for neighbour in ((x - 2, y), (x + 2, y), (x, y - 2), (x, y + 2)):
            if neighbour in remaining:
                remaining.remove(neighbour)
                pending.append(neighbour)
                region.append(neighbour)
    if len(region) > 30:
        xs, ys = zip(*region)
        bound = (min(xs), min(ys), max(xs), max(ys))
        if max(bound[2] - bound[0], bound[3] - bound[1]) < (right - left) * 50 / 360:
            regions.append((region, bound))
if not regions:
    raise RuntimeError('No isolated ball region was found')
regions.sort(key=lambda item: len(item[0]), reverse=True)
bound = regions[0][1]
centre = ((bound[0] + bound[2]) / 2, (bound[1] + bound[3]) / 2)
radius = (right - left) * 35 / 360
selected = []
for region, other in regions:
    cx, cy = (other[0] + other[2]) / 2, (other[1] + other[3]) / 2
    if (cx - centre[0]) ** 2 + (cy - centre[1]) ** 2 < radius ** 2:
        selected.extend(region)
xs, ys = zip(*selected)
print(json.dumps({'x': (min(xs) + max(xs)) / 2,
                  'y': (min(ys) + max(ys)) / 2,
                  'pixels': len(selected)}))
