# Usage: python3 keyboard_table.py <probe.txt> [t0 t1]   (t0/t1 default: 0.15 s before the first touch to 1.2 s after the last)
# Per probe frame: card minX values, the keyboard window's host (UIInputSetHostView) frame, each wrapper (x, w, right)
# and shadow alpha, and the first responder.
import sys, re
lines = open(sys.argv[1]).read().splitlines()
marks = [l for l in lines if ' MARK ' in l]
touches = [float(l.split()[0]) for l in marks if 'touch began' in l or ' push' in l or ' pop' in l]
t0 = float(sys.argv[2]) if len(sys.argv) > 2 else (min(touches) - 0.15 if touches else 0)
t1 = float(sys.argv[3]) if len(sys.argv) > 3 else (max(touches) + 1.2 if touches else 1e12)
rows = {}
for l in lines:
    p = l.split(' ', 2)
    if len(p) < 3: continue
    try: t = float(p[0])
    except: continue
    if t < t0 or t > t1: continue
    key = round(t, 3)
    r = rows.setdefault(key, {})
    if p[1] == 'CARDS':
        r['cards'] = [round(float(x), 1) for x in re.findall(r'0x[0-9a-f]+:(-?[0-9.]+)', p[2].split(' SCREENS')[0])]
        r['top'] = p[2].split(' TOP ')[-1]
    elif p[1] == 'KB':
        seg = p[2].split('UIRemoteKeyboardWindow', 1)
        rk = seg[1].split(' | ')[0] if len(seg) > 1 else ''
        host = re.findall(r'UIInputSetHostView:(-?[0-9.]+),(-?[0-9.]+),', rk)
        r['host'] = f"{float(host[0][0]):.0f},{float(host[0][1]):.0f}" if host else '-'
        r['wraps'] = [(round(float(a), 1), round(float(c), 1), round(float(a) + float(c), 1)) for a, b, c, d in re.findall(r'WRAP:(-?[0-9.]+),(-?[0-9.]+),(-?[0-9.]+),(-?[0-9.]+)', rk)]
        r['shadow'] = re.findall(r'SHADOW:-?[0-9.]+,[0-9.]+:a([0-9.]+)', rk)
        r['fr'] = p[2].split(' FR ')[-1]
    elif p[1] == 'MARK':
        r.setdefault('marks', []).append(p[2][:110])
for t in sorted(rows):
    r = rows[t]
    s = f"{t:.3f}"
    if 'cards' in r: s += f" cards {r['cards']} top {r['top']}"
    if 'host' in r: s += f" host {r['host']} wraps {r['wraps']} sh {r['shadow']} FR {r['fr']}"
    for m in r.get('marks', []):
        if not m.startswith('ANIM'): s += f" <{m}>"
    print(s)
