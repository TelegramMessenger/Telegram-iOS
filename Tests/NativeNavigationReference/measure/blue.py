# Usage: python3 blue.py <framesdir> <video> <t0> <t1> > out.txt
# Extracts the frames in [t0, t1] with their pts (VFR: only changed frames are stored) and prints "pts bluecount",
# the number of clearly blue pixels in the bar's right capsule area. Run this first: bbox.py and delta.py read its frames.
import sys, os, subprocess, re
from PIL import Image
d, video, t0, t1 = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
os.makedirs(d, exist_ok=True)
for f in os.listdir(d):
    if f.endswith('.png'): os.remove(os.path.join(d, f))
log = subprocess.run(["ffmpeg", "-v", "info", "-i", video, "-vf", f"select='between(t,{t0},{t1})',showinfo", "-fps_mode", "passthrough", os.path.join(d, "f%04d.png")], capture_output=True, text=True).stderr
pts = [float(m.group(1)) for m in re.finditer(r"pts_time:([0-9.]+)", log)]
files = sorted(f for f in os.listdir(d) if f.endswith('.png'))
for t, f in zip(pts, files):
    im = Image.open(os.path.join(d, f)).convert('RGB').crop((310 * 3, 55 * 3, 400 * 3, 115 * 3)); px = im.load()
    blue = sum(1 for x in range(0, im.width, 2) for y in range(0, im.height, 2) if px[x, y][2] > px[x, y][0] + 60)
    print(f"{t:6.3f} {blue}")
