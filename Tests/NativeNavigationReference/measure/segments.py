# Usage: python3 segments.py <framesdir> <video>
# The frames must be every frame of <video>, extracted in order (blue.py or `ffmpeg -fps_mode passthrough`, scaled to
# 402 pt wide). Prints the spans where a static content band (y 300-440 pt) and the bar (y 40-130 pt) move, with
# ffprobe's timestamps: how long a push or pop takes to come to rest. Animated content (emoji) in a band reads as
# motion, so keep it out of the bands.
import os,subprocess,sys
from PIL import Image, ImageChops, ImageStat
d, video = sys.argv[1], sys.argv[2]
pts=[float(x.strip(',')) for x in subprocess.run(["ffprobe","-v","error","-select_streams","v","-show_entries","frame=pts_time","-of","csv=p=0",video],capture_output=True,text=True).stdout.split() if x.strip(',')]
files=sorted(f for f in os.listdir(d) if f.endswith('.png'))
assert len(pts)==len(files), (len(pts), len(files))
prev=None; rows=[]
for t,f in zip(pts,files):
    im=Image.open(os.path.join(d,f)).convert('L')
    if prev is not None:
        rows.append((t,f,ImageStat.Stat(ImageChops.difference(im.crop((0,300,402,440)),prev.crop((0,300,402,440)))).mean[0],ImageStat.Stat(ImageChops.difference(im.crop((0,40,402,130)),prev.crop((0,40,402,130)))).mean[0]))
    prev=im
for idx,name in [(2,'band'),(3,'bar')]:
    seg=None
    for r in rows:
        if r[idx]>0.3:
            if seg is None: seg=[r[0],r[0],r[1]]
            else: seg[1]=r[0]
        elif seg and r[0]-seg[1]>0.15:
            print(f"{name} motion {seg[0]:.3f} -> {seg[1]:.3f} ({seg[1]-seg[0]:.3f}) from {seg[2]}"); seg=None
    if seg: print(name,"open",seg)
