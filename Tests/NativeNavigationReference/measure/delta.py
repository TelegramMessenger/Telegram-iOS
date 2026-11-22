# Usage: python3 delta.py <framesdir> | paste - <blue.py output>
# Per frame: mean absolute change of the capsule crop against the previous frame (when anything starts moving) and
# the mean blue-minus-red (tint progress, mixed with the tinted area).
import sys, os
from PIL import Image, ImageChops, ImageStat
d = sys.argv[1]
files = sorted(f for f in os.listdir(d) if f.endswith('.png'))
prev = None
for f in files:
    im = Image.open(os.path.join(d, f)).convert('RGB').crop((310 * 3, 55 * 3, 400 * 3, 115 * 3))
    r, g, b = ImageStat.Stat(im).mean
    dv = sum(ImageStat.Stat(ImageChops.difference(im, prev)).mean) if prev else 0
    print(f"{f} delta={dv:.1f} b-r={b - r:.1f}")
    prev = im
