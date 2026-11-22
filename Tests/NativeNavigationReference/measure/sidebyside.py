# Usage: python3 sidebyside.py <framesA> <videoA> <framesB> <videoB> <t0A> <t0B> <out.png>
# Two films' bars (y 40-150 pt) side by side every 33 ms from their own start times: native and ours, a push or a pop.
import os,subprocess,sys
from PIL import Image, ImageDraw
def load(d, video):
    pts=[float(x.strip(',')) for x in subprocess.run(["ffprobe","-v","error","-select_streams","v","-show_entries","frame=pts_time","-of","csv=p=0",video],capture_output=True,text=True).stdout.split() if x.strip(',')]
    files=sorted(f for f in os.listdir(d) if f.endswith('.png'))
    return list(zip(pts,[os.path.join(d,f) for f in files]))
def at(frames, t):
    best=None
    for p,f in frames:
        if p<=t+1e-6: best=f
    return best
a=load(sys.argv[1], sys.argv[2]); b=load(sys.argv[3], sys.argv[4])
ta=float(sys.argv[5]); tb=float(sys.argv[6]); out=sys.argv[7]
steps=[i*0.033 for i in range(0,17)]
crop=(0,40,402,150)
w=402; h=crop[3]-crop[1]
sheet=Image.new('RGB',(w*2+60, h*len(steps)),'white')
dr=ImageDraw.Draw(sheet)
for i,s in enumerate(steps):
    for j,(fr,t0) in enumerate([(a,ta),(b,tb)]):
        f=at(fr,t0+s)
        if f: sheet.paste(Image.open(f).convert('RGB').crop(crop),(60+j*w,i*h))
    dr.text((4,i*h+4),f"+{int(s*1000)}ms",fill=(255,0,0))
sheet.save(out); print(sheet.size)
