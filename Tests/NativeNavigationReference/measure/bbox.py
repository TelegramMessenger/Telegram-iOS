# Usage: python3 bbox.py <framesdir> <blue.py output>
# Bounding box, in points, of the blue (tinted) capsule per frame: the most reliable shape measure once it is tinted.
import sys, os
from PIL import Image
d, ptsf = sys.argv[1], sys.argv[2]
pts = [l.split()[0] for l in open(ptsf)]
files = sorted(f for f in os.listdir(d) if f.endswith('.png'))
for t, f in zip(pts, files):
    im = Image.open(os.path.join(d, f)).convert('RGB').crop((290 * 3, 45 * 3, 402 * 3, 125 * 3)); px = im.load()
    xs = []; ys = []
    for y in range(0, im.height):
        for x in range(0, im.width):
            r, g, b = px[x, y]
            if b > r + 40:
                xs.append(x); ys.append(y)
    if len(xs) > 200:
        print(f"{t} w={(max(xs)-min(xs)+1)/3:5.1f} h={(max(ys)-min(ys)+1)/3:5.1f} cx={(290*3+(max(xs)+min(xs))/2)/3:6.1f}")
