#!/usr/bin/env python3
"""Turn a simulator screen recording into contact sheets, per-frame numbers and element tracks, to judge an animation.

    python3 tools/animation_sheet.py VIDEO OUT_DIR [--start S] [--end E] [--scale K] [--crop X,Y,W,H]
                                     [--track NAME=X,Y,W,H ...] [--track-range PT] [--tile-width PX]
                                     [--columns N] [--rows N]

VIDEO is a recording from `xcrun simctl io <udid> recordVideo` (see AGENTS.md, "Visual features and animations").
All geometry (--crop, --track, every number printed) is in points: the recording's pixels divided by --scale (3, the
simulators' screen scale, by default).

Writes into OUT_DIR:
  sheet-NN.png  every frame in [S, E], tiled in time order, each labelled `#index  t=seconds  +ms since previous`;
                a flagged frame has a red label and frame; tracked regions are outlined where they were found.
  motion.png    per frame: how much the picture changed since the previous frame (bars), the interval since the
                previous frame (dots; dashes at the median interval) and how far the picture still is from the last
                frame, the resting state (green line).
  tracks.png    with --track: each region's vertical offset from its resting place per frame, one line per region.
  frames.tsv    index, time, interval, change, distance from the last frame, changed region, flags and each track's
                offset and match error, for every frame.
  frames/       the frames themselves, numbered as on the sheets.
and prints a summary: when the motion starts and settles, every time the picture passes its resting state and comes
back out, every flagged frame, each track's path (where it starts, how far past its rest it goes, when it settles) and,
with several tracks, how far apart they ever are.

The distance from the last frame is the coarse read of an animation's shape: an ease-out falls to 0 and stays there; a
spring falls, touches its rest and rises again by its overshoot before settling; a hitch is a step in it. It is
unsigned and measures the whole picture (or the --crop).

A track is the precise read: a region of the reference frame (the rest: the last frame, or the first with
--track-reference first for something leaving), in points, is looked for in every frame by shifting it vertically (within --track-range) to where it matches best, so its offset is signed and in points: negative above
its rest, positive below. Several tracks answer "do these move together": in every frame where all are found their
offsets must agree. Pick regions with texture (text, icons, edges), wholly inside the element, and clear of anything
that moves differently; a flat colour matches anywhere. A region is "not found" in a frame (blank in the table) when its
best match is still poor (mean error over --track-tolerance), e.g. while it is still faded out or covered.

The recording is variable-rate: the simulator writes a frame only when the screen changed, stamped with its own time
(1/600 s units), at the display's rate while something moves (60 to 120 Hz measured). So the frames are taken as they
are (no resampling) and time always comes from each frame's own presentation timestamp (ffprobe's; see `extract`),
never from its index.

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
import shutil
import statistics
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat

# The size frames are compared at for the whole-picture numbers: quick, and still sees a few points of motion.
COMPARE_WIDTH = 160
# A frame whose mean absolute change (0...255) is below this is treated as unchanged.
STILL_THRESHOLD = 0.05
TRACK_COLOURS = [(220, 60, 60), (40, 120, 220), (30, 160, 60), (200, 130, 0), (150, 60, 200), (0, 160, 170)]


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def frame_times(video):
    """Every frame's presentation time, in the order the decoder emits the frames (ffprobe's frame pts)."""
    result = run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "frame=pts_time,best_effort_timestamp_time", "-of", "csv=p=0", video])
    times = []
    for line in result.stdout.splitlines():
        fields = [f for f in line.split(",") if f]
        if not fields:
            continue
        value = fields[0] if fields[0] != "N/A" else fields[-1]
        times.append(float(value))
    return times


def extract(video, out_dir, start, end, crop, scale):
    """The frames in [start, end] as PNGs in points (the recording scaled down by `scale`), in time order, each with its
    own presentation time.

    The times come from ffprobe, not from ffmpeg's own (showinfo, `select` on `t`): the simulator's H.264 can carry
    a duplicated timestamp, after which ffmpeg falls back to each frame's decode timestamp, seconds behind its
    presentation time (measured: 11.66 s, then 8.07 s for the next frame). The frames still come out in presentation
    order, so the images are taken in ffmpeg's order and the range is applied here."""
    frames_dir = os.path.join(out_dir, "frames")
    if os.path.isdir(frames_dir):
        shutil.rmtree(frames_dir)
    raw_dir = os.path.join(out_dir, "frames-decoded")
    if os.path.isdir(raw_dir):
        shutil.rmtree(raw_dir)
    os.makedirs(frames_dir)
    os.makedirs(raw_dir)
    filters = []
    if crop:
        x, y, w, h = (round(v * scale) for v in crop)
        filters.append(f"crop={w}:{h}:{x}:{y}")
    filters.append(f"scale=iw/{scale}:-2:flags=area")
    run([
        "ffmpeg", "-hide_banner", "-nostdin", "-y", "-i", video,
        "-vf", ",".join(filters), "-fps_mode", "passthrough",
        os.path.join(raw_dir, "%05d.png"),
    ])
    times = frame_times(video)
    paths = sorted(os.path.join(raw_dir, name) for name in os.listdir(raw_dir) if name.endswith(".png"))
    if len(times) != len(paths):
        sys.exit(f"ffmpeg wrote {len(paths)} frames but ffprobe lists {len(times)}")
    frames = []
    for path, time in zip(paths, times):
        if (start is not None and time < start) or (end is not None and time > end):
            continue
        target = os.path.join(frames_dir, f"{len(frames):05d}.png")
        os.replace(path, target)
        frames.append((target, time))
    shutil.rmtree(raw_dir)
    return frames


def compare_image(path):
    image = Image.open(path).convert("L")
    height = max(1, round(image.height * COMPARE_WIDTH / image.width))
    return image.resize((COMPARE_WIDTH, height), Image.BILINEAR)


def measure(frames):
    """Per frame: interval since the previous one (ms), mean change since it and distance from the last frame (both
    mean absolute differences, 0...255) and the changed region, in points."""
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
        rows.append({"index": index, "time": time, "interval": interval, "change": change, "to_final": to_final, "region": region, "flags": [], "tracks": {}})
        previous = small
        previous_time = time
    return rows


def flag(rows):
    intervals = [r["interval"] for r in rows[1:] if r["change"] > STILL_THRESHOLD]
    median = statistics.median(intervals) if intervals else 0.0
    # A gap counts only in the animation being judged, not in a spinner or a caret that draws at its own lower rate.
    significant = 0.05 * max([r["change"] for r in rows] + [0.0])
    for i, row in enumerate(rows):
        if i == 0:
            continue
        if median > 0.0 and row["change"] > max(STILL_THRESHOLD, significant) and row["interval"] > 1.5 * median:
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


def parse_track(text):
    name, _, rect = text.partition("=")
    values = [int(round(float(v))) for v in rect.split(",")]
    if not name or len(values) != 4:
        sys.exit(f"--track wants NAME=X,Y,W,H, got {text!r}")
    return name, tuple(values)


def track(frames, rows, name, rect, search, tolerance, reference):
    """The region `rect` of the reference frame (the last, or the first) looked for in every frame by a vertical shift
    within ±`search` points: the shift with the least mean absolute difference (coarse in steps of 2, then refined),
    and that difference."""
    x, y, w, h = rect
    template = Image.open(frames[-1 if reference == "last" else 0][0]).convert("L").crop((x, y, x + w, y + h))
    for row, (path, _) in zip(rows, frames):
        image = Image.open(path).convert("L")

        def error(dy):
            top = y + dy
            if top < 0 or top + h > image.height:
                return None
            return ImageStat.Stat(ImageChops.difference(image.crop((x, top, x + w, top + h)), template)).mean[0]

        best = None
        for dy in range(-search, search + 1, 2):
            e = error(dy)
            if e is not None and (best is None or e < best[1]):
                best = (dy, e)
        if best is not None:
            for dy in range(best[0] - 2, best[0] + 3):
                e = error(dy)
                if e is not None and e < best[1]:
                    best = (dy, e)
        found = best is not None and best[1] <= tolerance
        row["tracks"][name] = (best[0] if found else None, best[1] if best else None)


def track_summary(rows, name):
    path = [(r, r["tracks"][name][0]) for r in rows if r["tracks"][name][0] is not None]
    if not path:
        return [f"track {name}: never found (raise --track-tolerance, or pick a region with more texture)"]
    first_row, first = path[0]
    lines = [f"track {name}: found from #{first_row['index']} t={first_row['time']:.3f} at {first:+d} pt"]
    # Past the rest: the furthest it goes on the far side from where it was first found, after first reaching the rest.
    side = 1 if first > 0 else -1 if first < 0 else 0
    reached = next((i for i, (_, dy) in enumerate(path) if side != 0 and dy * side <= 0), None)
    if reached is not None:
        beyond = max(path[reached:], key=lambda p: -p[1] * side)
        amount = -beyond[1] * side
        if amount > 0:
            lines.append(f"  reaches its rest at #{path[reached][0]['index']} t={path[reached][0]['time']:.3f}, goes {amount} pt past it (#{beyond[0]['index']} t={beyond[0]['time']:.3f})")
        else:
            lines.append(f"  reaches its rest at #{path[reached][0]['index']} t={path[reached][0]['time']:.3f} without going past it")
        crossings = sum(1 for (_, a), (_, b) in zip(path[reached:], path[reached + 1:]) if (a > 1 and b < -1) or (a < -1 and b > 1))
        if crossings:
            lines.append(f"  crosses its rest {crossings} more time(s) after that")
    settled = None
    for r, dy in reversed(path):
        if abs(dy) > 1:
            break
        settled = r
    if settled is not None:
        lines.append(f"  within 1 pt of rest from #{settled['index']} t={settled['time']:.3f}")
    return lines


def togetherness(rows, names):
    lines = []
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            pairs = [(r, r["tracks"][a][0] - r["tracks"][b][0]) for r in rows if r["tracks"][a][0] is not None and r["tracks"][b][0] is not None]
            if not pairs:
                lines.append(f"{a} vs {b}: never both found")
                continue
            worst = max(pairs, key=lambda p: abs(p[1]))
            lines.append(f"{a} vs {b}: {len(pairs)} frames together, apart by at most {abs(worst[1])} pt (#{worst[0]['index']} t={worst[0]['time']:.3f}: {a} {worst[0]['tracks'][a][0]:+d}, {b} {worst[0]['tracks'][b][0]:+d})")
    return lines


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def sheets(frames, rows, out_dir, columns, rows_per_sheet, tile_width, tracks):
    label_font = font(14)
    source_w, source_h = Image.open(frames[0][0]).size
    k = tile_width / source_w
    tile_w, tile_h = tile_width, max(1, round(source_h * k))
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
            sheet.paste(Image.open(frames[i][0]).convert("RGB").resize((tile_w, tile_h), Image.LANCZOS), (x, y + label_h))
            for t, (name, (rx, ry, rw, rh)) in enumerate(tracks):
                dy = row["tracks"][name][0]
                if dy is None:
                    continue
                c = TRACK_COLOURS[t % len(TRACK_COLOURS)]
                draw.rectangle((x + rx * k, y + label_h + (ry + dy) * k, x + (rx + rw) * k, y + label_h + (ry + dy + rh) * k), outline=c, width=1)
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


def track_chart(rows, names, out_dir):
    """Each track's offset per frame, on one axis: lines that lie on each other moved together."""
    width = max(640, 8 * len(rows) + 90)
    height = 420
    image = Image.new("RGB", (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(image)
    small = font(12)
    left, top, bottom = 60, 30 + 16 * len(names), height - 30
    step = (width - left - 20) / max(1, len(rows))
    values = [r["tracks"][n][0] for r in rows for n in names if r["tracks"][n][0] is not None]
    if not values:
        return None
    low, high = min(values + [0]), max(values + [0])
    pad = max(2.0, (high - low) * 0.05)
    low, high = low - pad, high + pad

    def y_of(v):
        return bottom - (bottom - top) * (v - low) / (high - low)

    for x in range(left, width - 20, 8):
        draw.line((x, y_of(0), x + 4, y_of(0)), fill=(120, 120, 120))
    draw.text((4, y_of(0) - 7), "rest 0", fill=(80, 80, 80), font=small)
    draw.text((4, top - 2), f"{high:+.0f} pt", fill=(80, 80, 80), font=small)
    draw.text((4, bottom - 12), f"{low:+.0f} pt", fill=(80, 80, 80), font=small)
    for i in range(0, len(rows), 10):
        draw.text((left + i * step, bottom + 4), f"#{i}", fill=(0, 0, 0), font=small)
    for t, name in enumerate(names):
        c = TRACK_COLOURS[t % len(TRACK_COLOURS)]
        draw.text((left, 6 + 16 * t), f"{name} (positive: below its rest)", fill=c, font=small)
        segment = []
        for i, r in enumerate(rows):
            dy = r["tracks"][name][0]
            if dy is None:
                if len(segment) > 1:
                    draw.line(segment, fill=c, width=2)
                segment = []
                continue
            segment.append((left + i * step + step * 0.5, y_of(dy)))
        if len(segment) > 1:
            draw.line(segment, fill=c, width=2)
    path = os.path.join(out_dir, "tracks.png")
    image.save(path)
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("video")
    parser.add_argument("out_dir")
    parser.add_argument("--start", type=float, help="first second to keep (the recording's own clock)")
    parser.add_argument("--end", type=float, help="last second to keep")
    parser.add_argument("--scale", type=float, default=3.0, help="recording pixels per point (default 3)")
    parser.add_argument("--crop", help="X,Y,W,H in points: look at this part of the screen only")
    parser.add_argument("--track", action="append", default=[], help="NAME=X,Y,W,H in points (after --crop), as it is at rest in the reference frame; repeatable")
    parser.add_argument("--track-range", type=int, default=260, help="how far, in points, a track is looked for above and below its rest (default 260)")
    parser.add_argument("--track-tolerance", type=float, default=12.0, help="worst mean error (0...255) a track still counts as found at (default 12)")
    parser.add_argument("--track-reference", choices=["last", "first"], default="last", help="the frame the tracked regions are at rest in: the last (an element arriving, the default) or the first (one leaving)")
    parser.add_argument("--tile-width", type=int, default=200, help="width of one frame on the sheet (default 200)")
    parser.add_argument("--columns", type=int, default=8)
    parser.add_argument("--rows", type=int, default=4, help="rows per sheet (default 4)")
    args = parser.parse_args()

    crop = tuple(float(v) for v in args.crop.split(",")) if args.crop else None
    tracks = [parse_track(t) for t in args.track]
    os.makedirs(args.out_dir, exist_ok=True)
    frames = extract(args.video, args.out_dir, args.start, args.end, crop, args.scale)
    if not frames:
        sys.exit("no frames in that range")
    rows = measure(frames)
    median = flag(rows)
    for name, rect in tracks:
        track(frames, rows, name, rect, args.track_range, args.track_tolerance, args.track_reference)
    names = [name for name, _ in tracks]

    with open(os.path.join(args.out_dir, "frames.tsv"), "w", newline="") as f:
        writer = csv.writer(f, delimiter="\t")
        writer.writerow(["index", "time_s", "interval_ms", "change", "to_final", "changed_region", "flags"] + [c for n in names for c in (f"{n}_dy", f"{n}_err")])
        for row in rows:
            cells = []
            for n in names:
                dy, err = row["tracks"][n]
                cells += ["-" if dy is None else dy, "-" if err is None else f"{err:.1f}"]
            writer.writerow([row["index"], f"{row['time']:.4f}", f"{row['interval']:.1f}", f"{row['change']:.2f}", f"{row['to_final']:.2f}", row["region"] or "", ",".join(row["flags"])] + cells)

    written = sheets(frames, rows, args.out_dir, args.columns, args.rows, args.tile_width, tracks)
    motion = chart(rows, median, args.out_dir)
    tracks_png = track_chart(rows, names, args.out_dir) if names else None

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
    for name in names:
        for line in track_summary(rows, name):
            print(line)
    for line in togetherness(rows, names):
        print(line)
    for path in written + [motion] + ([tracks_png] if tracks_png else []) + [os.path.join(args.out_dir, "frames.tsv")]:
        print(path)


if __name__ == "__main__":
    main()
