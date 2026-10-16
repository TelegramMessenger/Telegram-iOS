# Usage: python3 probe_series.py <probe.txt> [--ours <t0>] [--after 0.5]
# Prints the bar's right capsule frame by frame around each change.
#  - Native (CapsuleProbe in ../main.swift, -probe 1): around every MARK line, the glass layer's window frame, and
#    the press view's transform. In SwiftUI's toolbar both the press and the pulse land in the glass's bounds and the
#    press view's transform, so native cannot be split by layer: compare against -noopEdit 1 (press alone) and
#    -scenario editCheck (pulse alone).
#  - Ours (inject_probe.py): around <t0> (CACurrentMediaTime of the change), our pulse (the container's transform),
#    the visible height, and the press, derived as visible / 44 / pulse.
import sys
args = sys.argv[1:]
path = args[0]
after = float(args[args.index('--after') + 1]) if '--after' in args else 0.5
lines = open(path).read().splitlines()

def native():
    for mark in [l for l in lines if ' MARK ' in l]:
        t0 = float(mark.split()[0])
        print('===', mark)
        previous = None
        for line in lines:
            if ' ALL ' not in line:
                continue
            t = float(line.split()[0])
            if not (t0 - 0.05 <= t <= t0 + after):
                continue
            glass = [item for item in line.split(' ALL ')[1].split(' PRESS ')[0].strip().split(';') if item]
            press = [item for item in line.split(' PRESS ')[1].strip().split(';') if item] if ' PRESS ' in line else []
            if not glass:
                continue
            x, y, w, h, o = map(float, glass[0].split(':')[1].split(',')[:5])
            p = float(press[0].split(':')[1].split(',')[1]) if press else float('nan')
            text = f'glass {w:5.1f} x {h:5.1f}  h/44 {h / 44:.4f}  press view m22 {p:.4f}  cx {x:5.1f}  opacity {o:.2f}'
            if text != previous:
                print(f'{t - t0:+.4f}  {text}')
            previous = text

def ours(t0):
    previous = None
    for line in lines:
        parts = line.split(' OURS ')
        if len(parts) < 2:
            continue
        t = float(parts[0])
        if not (t0 - 0.1 <= t <= t0 + after):
            continue
        found = {}
        for item in parts[1].split(';'):
            if item:
                kind, _, values = item.split(':')
                found.setdefault(kind, list(map(float, values.split(','))))
        if 'C' not in found or 'E' not in found:
            continue
        pulse = found['C'][5]
        h = found['E'][3]
        text = f'pulse {pulse:.4f}  visible {found["E"][2]:5.1f} x {h:5.2f} ({h / 44:.4f})  press {h / 44 / pulse:.4f}'
        if text != previous:
            print(f'{t - t0:+.4f}  {text}')
        previous = text

if '--ours' in args:
    ours(float(args[args.index('--ours') + 1]))
else:
    native()
