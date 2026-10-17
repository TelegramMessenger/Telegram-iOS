#!/usr/bin/env python3
"""Turn a simulator screen recording into contact sheets and a per-frame table, to judge an animation from stills.

    python3 tools/animation_sheet.py VIDEO OUT_DIR [--start S] [--end E] [--crop X,Y,W,H] [--tile-width PX]
                                     [--columns N] [--rows N]

VIDEO is a recording from `xcrun simctl io <udid> recordVideo` (see AGENTS.md, "Visual features and animations").
Writes into OUT_DIR:
  sheet-NN.png  every frame in [S, E], tiled in time order, each labelled `#index  t=seconds  +ms since previous`;
                a flagged frame has a red label and frame.
  motion.png    per frame: how much the picture changed since the previous frame (bars), the interval since the
                previous frame (dots; dashes at the median interval) and how far the picture still is from the last
                frame, the resting state (green line).
  frames.tsv    index, time, interval, change, distance from the last frame, changed region and flags for every frame.
and prints a summary: when the motion starts, when it settles, every time it passes its resting state and comes back
out (a spring's overshoot and oscillation), and every flagged frame.

The distance from the last frame is the automatic read of an animation's shape: an ease-out falls to 0 and stays there;
a spring falls, touches its rest (a minimum) and rises again by its overshoot before settling; a hitch is a step in it.
It is unsigned (it says how far, not which way), so a pass through the rest reads as a minimum, and it measures the
whole picture, so --crop to the element that is supposed to move when other things move too.

The recording is variable-rate: the simulator writes a frame only when the screen changed, stamped with its own time
(1/600 s units), at the display's ~60 Hz while something moves. So the frames are taken as they are (no resampling)
and time always comes from each frame's own timestamp, never from its index.

Flags (heuristics; look at the frames they point to before believing them):
  gap    the interval since the previous frame is over 1.5x the median interval while the picture is changing: a frame
         drawn late (a hitch) or a stall (the recorder writes nothing while the picture stands still, so a stall shows
         as one long interval).
  jump   the frame changed over 3x as much as the frames around it typically did: a snap, a teleport, an element
         appearing or vanishing at once in the middle of otherwise smooth motion.

The recorder sometimes writes a near-copy a few ms after a frame; such a frame changes almost nothing and is not a
stall.
"""

import argparse
import csv
import os
import re
import shutil
import statistics
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat

# The size frames are compared at: small enough to be quick, large enough to see a few points of motion.
COMPARE_WIDTH = 160
# A frame whose mean absolute change (0...255) is below this is treated as unchanged.
STILL_THRESHOLD = 0.05


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def extract(video, out_dir, start, end, crop, tile_width):
    """The frames in [start, end] as PNGs, each with its own timestamp (showinfo's pts_time)."""
    frames_dir = os.path.join(out_dir, "frames")
    if os.path.isdir(frames_dir):
        shutil.rmtree(frames_dir)
    os.makedirs(frames_dir)
    filters = []
    condition = []
    if start is not None:
        condition.append(f"gte(t,{start})")
    if end is not None:
        condition.append(f"lte(t,{end})")
    if condition:
        filters.append("select='" + "*".join(condition) + "'")
    if crop:
        x, y, w, h = crop
        filters.append(f"crop={w}:{h}:{x}:{y}")
    filters.append(f"scale={tile_width}:-2:flags=area")
    filters.append("showinfo")
    result = run([
        "ffmpeg", "-hide_banner", "-nostdin", "-y", "-i", video,
        "-vf", ",".join(filters), "-fps_mode", "passthrough",
        os.path.join(frames_dir, "%05d.png"),
    ])
    times = [float(m.group(1)) for m in re.finditer(r"\bn:\s*\d+.*?\bpts_time:\s*([0-9.eE+-]+)", result.stderr)]
    paths = sorted(os.path.join(frames_dir, name) for name in os.listdir(frames_dir) if name.endswith(".png"))
    if len(times) != len(paths):
        sys.exit(f"ffmpeg wrote {len(paths)} frames but reported {len(times)} timestamps")
    return list(zip(paths, times))


def compare_image(path):
    image = Image.open(path).convert("L")
    height = max(1, round(image.height * COMPARE_WIDTH / image.width))
    return image.resize((COMPARE_WIDTH, height), Image.BILINEAR)


def measure(frames):
    """Per frame: interval since the previous one (ms), mean change since it and distance from the last frame (both
    mean absolute differences, 0...255) and the changed region, in the tile's coordinates."""
    rows = []
    previous = None
    previous_time = None
    final = compare_image(frames[-1][0])
    for index, (path, time) in enumerate(frames):
        small = compare_image(path)
        to_final = ImageStat.Stat(ImageChops.difference(small, final)).mean[0]
        change = 0.0
        region = None
        if previous is not None:
            diff = ImageChops.difference(small, previous)
            change = ImageStat.Stat(diff).mean[0]
            box = diff.point(lambda v: 255 if v > 12 else 0).getbbox()
            if box:
                scale = Image.open(path).width / COMPARE_WIDTH
                region = tuple(round(v * scale) for v in box)
        interval = (time - previous_time) * 1000.0 if previous_time is not None else 0.0
        rows.append({"index": index, "time": time, "interval": interval, "change": change, "to_final": to_final, "region": region, "flags": []})
        previous = small
        previous_time = time
    return rows


def flag(rows):
    intervals = [r["interval"] for r in rows[1:] if r["change"] > STILL_THRESHOLD]
    median = statistics.median(intervals) if intervals else 0.0
    for i, row in enumerate(rows):
        if i == 0:
            continue
        if median > 0.0 and row["change"] > STILL_THRESHOLD and row["interval"] > 1.5 * median:
            row["flags"].append("gap")
        # The window's median change, without the frame itself: robust to the recorder's near-copies.
        window = [rows[k]["change"] for k in range(max(1, i - 3), min(len(rows), i + 4)) if k != i]
        typical = statistics.median(window) if window else 0.0
        if row["change"] > 1.0 and row["change"] > 3.0 * typical:
            row["flags"].append("jump")
    return median


def settling(rows):
    """When the picture comes within 2% of its rest for good, and every pass through the rest: a minimum of the
    distance near the rest (under a quarter of the start's) that it comes back out of by more than 2% of the start's."""
    start = max(r["to_final"] for r in rows)
    near = max(0.3, 0.02 * start)
    settled = None
    for row in reversed(rows):
        if row["to_final"] > near:
            break
        settled = row
    passes = []
    i = 1
    while i < len(rows) - 1:
        low = rows[i]["to_final"]
        if low <= rows[i - 1]["to_final"] and low < rows[i + 1]["to_final"] and low < 0.25 * start:
            peak = i + 1
            while peak + 1 < len(rows) and rows[peak + 1]["to_final"] >= rows[peak]["to_final"]:
                peak += 1
            if rows[peak]["to_final"] - low > near:
                passes.append((rows[i], rows[peak], (rows[peak]["to_final"] - low) / start))
            i = peak
        i += 1
    return start, settled, passes


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def sheets(frames, rows, out_dir, columns, rows_per_sheet):
    label_font = font(14)
    tile_w, tile_h = Image.open(frames[0][0]).size
    label_h = 20
    per_sheet = columns * rows_per_sheet
    written = []
    for sheet_index, first in enumerate(range(0, len(frames), per_sheet)):
        chunk = list(range(first, min(first + per_sheet, len(frames))))
        lines = (len(chunk) + columns - 1) // columns
        sheet = Image.new("RGB", (columns * (tile_w + 4) + 4, lines * (tile_h + label_h + 4) + 4), (40, 40, 40))
        draw = ImageDraw.Draw(sheet)
        for slot, i in enumerate(chunk):
            x = 4 + (slot % columns) * (tile_w + 4)
            y = 4 + (slot // columns) * (tile_h + label_h + 4)
            row = rows[i]
            flagged = bool(row["flags"])
            colour = (255, 80, 80) if flagged else (230, 230, 230)
            text = f"#{i}  t={row['time']:.3f}  +{row['interval']:.1f}ms"
            if flagged:
                text += "  " + ",".join(row["flags"])
            draw.text((x + 2, y + 2), text, fill=colour, font=label_font)
            sheet.paste(Image.open(frames[i][0]).convert("RGB"), (x, y + label_h))
            if flagged:
                draw.rectangle((x - 2, y + label_h - 2, x + tile_w + 1, y + label_h + tile_h + 1), outline=(255, 80, 80), width=2)
        path = os.path.join(out_dir, f"sheet-{sheet_index + 1:02d}.png")
        sheet.save(path)
        written.append(path)
    return written


def chart(rows, median, out_dir):
    width = max(640, 6 * len(rows) + 90)
    height = 320
    image = Image.new("RGB", (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(image)
    small = font(12)
    left, top, bottom = 60, 38, height - 30
    span = bottom - top
    step = (width - left - 20) / max(1, len(rows))
    max_change = max([r["change"] for r in rows] + [1.0])
    max_interval = max([r["interval"] for r in rows] + [median * 2.0, 1.0])
    for i, row in enumerate(rows):
        x0 = left + i * step
        bar = span * row["change"] / max_change
        colour = (220, 60, 60) if row["flags"] else (80, 120, 220)
        draw.rectangle((x0, bottom - bar, x0 + max(1.0, step - 1.0), bottom), fill=colour)
        y = bottom - span * row["interval"] / max_interval
        draw.ellipse((x0, y - 2, x0 + 4, y + 2), fill=(30, 30, 30))
        if i % 10 == 0:
            draw.text((x0, bottom + 4), f"#{i}", fill=(0, 0, 0), font=small)
    max_to_final = max([r["to_final"] for r in rows] + [1.0])
    points = [(left + i * step + step * 0.5, bottom - span * r["to_final"] / max_to_final) for i, r in enumerate(rows)]
    if len(points) > 1:
        draw.line(points, fill=(30, 160, 60), width=2)
    if median > 0.0:
        y = bottom - span * median / max_interval
        for x in range(left, width - 20, 8):
            draw.line((x, y, x + 4, y), fill=(30, 30, 30))
    draw.text((4, top), "change", fill=(80, 120, 220), font=small)
    draw.text((4, top + 16), "interval", fill=(30, 30, 30), font=small)
    draw.text((4, top + 32), "to rest", fill=(30, 160, 60), font=small)
    draw.text((left, 2), f"bars: change since the previous frame (max {max_change:.1f}/255); green: distance from the last frame", fill=(0, 0, 0), font=small)
    draw.text((left, 18), f"dots: interval since the previous frame (max {max_interval:.1f} ms; dashes: median {median:.1f} ms)", fill=(0, 0, 0), font=small)
    path = os.path.join(out_dir, "motion.png")
    image.save(path)
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("video")
    parser.add_argument("out_dir")
    parser.add_argument("--start", type=float, help="first second to keep (the recording's own clock)")
    parser.add_argument("--end", type=float, help="last second to keep")
    parser.add_argument("--crop", help="X,Y,W,H in the recording's pixels, before scaling")
    parser.add_argument("--tile-width", type=int, default=200, help="width of one frame on the sheet (default 200)")
    parser.add_argument("--columns", type=int, default=8)
    parser.add_argument("--rows", type=int, default=4, help="rows per sheet (default 4)")
    args = parser.parse_args()

    crop = tuple(int(v) for v in args.crop.split(",")) if args.crop else None
    os.makedirs(args.out_dir, exist_ok=True)
    frames = extract(args.video, args.out_dir, args.start, args.end, crop, args.tile_width)
    if not frames:
        sys.exit("no frames in that range")
    rows = measure(frames)
    median = flag(rows)

    with open(os.path.join(args.out_dir, "frames.tsv"), "w", newline="") as f:
        writer = csv.writer(f, delimiter="\t")
        writer.writerow(["index", "time_s", "interval_ms", "change", "to_final", "changed_region", "flags"])
        for row in rows:
            writer.writerow([row["index"], f"{row['time']:.4f}", f"{row['interval']:.1f}", f"{row['change']:.2f}", f"{row['to_final']:.2f}", row["region"] or "", ",".join(row["flags"])])

    written = sheets(frames, rows, args.out_dir, args.columns, args.rows)
    motion = chart(rows, median, args.out_dir)

    moving = [r for r in rows if r["change"] > STILL_THRESHOLD]
    print(f"{len(rows)} frames, {rows[0]['time']:.3f}-{rows[-1]['time']:.3f} s; {len(moving)} changed; median interval while moving {median:.1f} ms")
    if moving:
        print(f"motion from {moving[0]['time']:.3f} s to {moving[-1]['time']:.3f} s ({(moving[-1]['time'] - moving[0]['time']) * 1000.0:.0f} ms)")
    start, settled, passes = settling(rows)
    if settled is not None:
        print(f"within 2% of the last frame from #{settled['index']} t={settled['time']:.3f} s")
    for low, high, amount in passes:
        print(f"  passes its rest at #{low['index']} t={low['time']:.3f}, back out to {amount * 100.0:.1f}% of the start's distance at #{high['index']} t={high['time']:.3f}")
    if not passes:
        print("  no pass through the rest: no overshoot, no oscillation")
    flagged = [r for r in rows if r["flags"]]
    for row in flagged:
        print(f"  #{row['index']} t={row['time']:.3f} +{row['interval']:.1f}ms change={row['change']:.2f} {','.join(row['flags'])}")
    if not flagged:
        print("  nothing flagged")
    for path in written + [motion, os.path.join(args.out_dir, "frames.tsv")]:
        print(path)


if __name__ == "__main__":
    main()
