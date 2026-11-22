#!/usr/bin/env python3
"""Measure D, the commit-to-display depth, against a running CoreListDemo pipeline probe.

D is how long after a main-thread turn's work the frame carrying that turn's commit is scanned out,
in display frames. `PhysicsScrollEngine.launchFlight` cannot derive it, and the residual it leaves is
`(D - 1) x frameTravel` -- see that function and the CoreList CLAUDE.md.

The app draws two bars on one 900 pt/s ramp from a shared origin: RED moved by a per-frame model
write (how the drag moves the list), BLUE by a CABasicAnimation on an explicit beginTime (how a baked
flight moves it). Their separation in one composited frame is `velocity x D`.

    python3 Tools/measure-pipeline-depth.py --udid <sim udid> --sweep

`--sweep` is the POSITIVE CONTROL and is not optional for a result you intend to believe: it re-runs
with a commanded lead on the animated bar, which must come back as an equal measured gap. An
instrument that reads zero is worth nothing until a known offset moves it.

Capture must be `simctl io recordVideo`. `simctl io screenshot` re-renders on demand rather than
sampling a composited frame -- measured, its gap wandered 0..37px with no stable value while the red
bar's own positions stayed cleanly quantized to one frame of travel, so the noise was all in the
capture.
"""

import argparse, glob, os, signal, statistics, subprocess, sys, tempfile, time

try:
    from PIL import Image
except ImportError:
    sys.exit("needs Pillow: python3 -m pip install Pillow")

BUNDLE_ID = "org.telegram.CoreListDemo"
VELOCITY = 900.0     # pt/s   — PipelineDepthProbe.velocity
TRAVEL = 600.0       # pt     — PipelineDepthProbe.travel (the ramp wraps here)


def record(udid, app, lead_ms, seconds, workdir):
    subprocess.run(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], capture_output=True)
    if app:
        subprocess.run(["xcrun", "simctl", "install", udid, app], capture_output=True, check=True)
    subprocess.run(["xcrun", "simctl", "launch", udid, BUNDLE_ID,
                    "-pipelineProbe", "1", "-probeLead", str(lead_ms)],
                   capture_output=True, check=True)
    time.sleep(2.5)                                   # let the ramp and the display link settle
    movie = os.path.join(workdir, f"probe_{lead_ms}.mp4")
    proc = subprocess.Popen(["xcrun", "simctl", "io", udid, "recordVideo",
                             "--codec", "h264", "--force", movie],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(seconds)
    proc.send_signal(signal.SIGINT)
    proc.wait(timeout=20)
    frames = os.path.join(workdir, f"frames_{lead_ms}")
    os.makedirs(frames, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-i", movie, "-fps_mode", "passthrough",
                    os.path.join(frames, "f_%04d.png")], capture_output=True)
    return frames


def centers(path, scale):
    """Bar centres in one frame, or None if either bar is mid-wrap.

    The bars are separated by x-half and required to be ~500px wide, which is what keeps the blue
    `Start` label and the blue selected tab-bar item out of the result — they were in it once, and
    the reading looked like a many-cycle drift rather than the obvious contamination it was.
    """
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    half = w // 2
    red_rows, blue_rows = [], []
    for y in range(h):
        r = sum(1 for x in range(0, half, 2)
                if px[x, y][0] > 170 and px[x, y][1] < 120 and px[x, y][2] < 120)
        b = sum(1 for x in range(half, w, 2)
                if px[x, y][2] > 170 and px[x, y][0] < 120 and 70 < px[x, y][1] < 200)
        if r > 150: red_rows.append(y)
        if b > 150: blue_rows.append(y)
    if not red_rows or not blue_rows:
        return None
    if red_rows[-1] - red_rows[0] > 40 or blue_rows[-1] - blue_rows[0] > 40:
        return None
    return (red_rows[0] + red_rows[-1]) / 2, (blue_rows[0] + blue_rows[-1]) / 2


def measure(frames, scale):
    cycle_px = TRAVEL * scale
    gaps, reds = [], []
    for p in sorted(glob.glob(os.path.join(frames, "f_*.png"))):
        c = centers(p, scale)
        if not c:
            continue
        gap = c[1] - c[0]
        while gap < -cycle_px / 2: gap += cycle_px
        while gap > cycle_px / 2: gap -= cycle_px
        reds.append(c[0]); gaps.append(gap)
    if len(gaps) < 20:
        return None
    steps = [reds[i + 1] - reds[i] for i in range(len(reds) - 1)]
    steps = [s for s in steps if 0 < s < 200]
    step_pt = statistics.median(steps) / scale          # the red bar only moves on a model write,
    hz = VELOCITY / step_pt                             # so its step size IS the display frame
    gap_pt = statistics.median(gaps) / scale
    return {"frames": len(gaps), "hz": hz, "gap_pt": gap_pt,
            "ms": gap_pt / VELOCITY * 1000.0,
            "frames_of_depth": (gap_pt / VELOCITY) * hz,
            "stdev_px": statistics.pstdev(gaps)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--udid", required=True)
    ap.add_argument("--app", help="path to CoreListDemo.app; omit to use what is installed")
    ap.add_argument("--seconds", type=float, default=4.0)
    ap.add_argument("--scale", type=float, default=3.0)
    ap.add_argument("--sweep", action="store_true", help="run the positive control (do this)")
    args = ap.parse_args()

    leads = [0.0]
    if args.sweep:
        leads = [-8.333, 0.0, 4.167, 8.333, 16.667, 33.333]

    with tempfile.TemporaryDirectory() as workdir:
        print(f"{'commanded':>12} {'measured':>10} {'residual':>10} {'frames':>7} {'Hz':>6} {'sd(px)':>7}")
        for lead in leads:
            r = measure(record(args.udid, args.app, lead, args.seconds, workdir), args.scale)
            if not r:
                print(f"{lead:>10.3f}ms   <no usable frames — is the probe tab running?>")
                continue
            print(f"{lead:>10.3f}ms {r['ms']:>9.2f}ms {r['ms'] - lead:>9.2f}ms "
                  f"{r['frames']:>7} {r['hz']:>6.1f} {r['stdev_px']:>7.1f}")
        print("\nD is the measured value at commanded lead 0, in frames. The other rows must track "
              "the command 1:1 or the instrument is not measuring anything.")


if __name__ == "__main__":
    main()
