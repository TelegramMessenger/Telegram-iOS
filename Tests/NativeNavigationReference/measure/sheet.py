# Usage: python3 sheet.py <framesdir> <out.png> <first> <last> [step]
# Contact sheet of the bar's right side (x 230..402 pt, y 40..130 pt), frame numbers in red; 1.5 px per pt.
import sys, os
from PIL import Image, ImageDraw
d, out, a, b = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
step = int(sys.argv[5]) if len(sys.argv) > 5 else 1
files = sorted(f for f in os.listdir(d) if f.endswith('.png'))[a - 1:b:step]
crops = []
for f in files:
    im = Image.open(os.path.join(d, f)).convert('RGB').crop((230 * 3, 40 * 3, 402 * 3, 130 * 3))
    im = im.resize((im.width // 2, im.height // 2))
    ImageDraw.Draw(im).text((4, 4), f[1:5], fill=(255, 0, 0))
    crops.append(im)
cols = 6
w, h = crops[0].size
sheet = Image.new('RGB', (w * cols, h * ((len(crops) + cols - 1) // cols)), 'white')
for i, c in enumerate(crops):
    sheet.paste(c, ((i % cols) * w, (i // cols) * h))
sheet.save(out)
print(len(crops), sheet.size)
