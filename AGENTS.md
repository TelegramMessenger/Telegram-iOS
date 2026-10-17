# AGENTS.md

Guidance for coding agents working in this repository. The project guide is [`CLAUDE.md`](CLAUDE.md): how to build,
which simulators to use, how to drive them (XcodeBuildMCP) and the invariants of each subsystem. Read it first.

## Visual features and animations: judge them from recorded frames

A green build and passing unit tests say nothing about how a change looks or moves. For any visual change, and always
for one that animates, record the simulator while it happens, turn the recording into images of its frames labelled
with their index and time, and evaluate the animation from those before calling the work done. Unit tests pin the
model (a choreography's values, a layout's frames); only the frames show what is drawn: what is clipped, what pops in,
what moves together and what lags, where it overshoots and whether it settles.

### 1. Know what correct looks like first

Write down, before recording, what the frames should show: which elements move, which move together, the direction,
roughly how long, whether a spring should overshoot and how many times, what must never be visible (a gap, a clipped
edge, an element standing still while its neighbours move). The evaluation is a comparison against this; without it
the frames only get described.

### 2. Record

Recording is passive: it does not touch the installed app or its state. Installing or replacing the app is not; follow
`CLAUDE.md` and the user's standing instructions on which simulator an agent may install on, and otherwise ask the user
to install the build and then record what they or you trigger.

```sh
U=<simulator udid>                       # xcrun simctl list devices booted
OUT=<scratch directory>                  # not the repo
xcrun simctl io "$U" recordVideo --codec=h264 --force "$OUT/anim.mp4" > "$OUT/rec.log" 2>&1 &
REC=$!
until grep -q "Recording started" "$OUT/rec.log"; do sleep 0.1; done
# … trigger the animation: XcodeBuildMCP taps/swipes, a deep link (xcrun simctl openurl), or ask the user …
sleep 1                                  # let it settle on camera
kill -INT $REC; wait $REC                # SIGINT finalizes the file
```

- Use `simctl io recordVideo`, not XcodeBuildMCP's `record_sim_video`: the latter resamples to a fixed rate (30 fps by
  default), which hides exactly the frame-level detail being looked for.
- The recording is **variable-rate**. The simulator writes a frame only when the screen changes, stamped with its own
  time (1/600 s units), about every 16.7 ms while something moves (measured on an iPhone 17 / iOS 26.5 simulator;
  the script prints the median). A still screen produces no frames, so a stall appears as one long interval, and time
  must always come from a frame's timestamp, never from its index. It also writes the odd near-copy a few ms after a
  frame.
- Frames are the device's pixels (3x: a 402 × 874 pt screen records at 1206 × 2622).
- Record the whole gesture with a little still time on both sides, once per path the change touches (open and close,
  each entry point, light and dark, with and without the optional content), and in slow motion only in addition to
  real speed, never instead: timing is part of what is being judged.

### 3. Turn it into frames

```sh
python3 tools/animation_sheet.py "$OUT/anim.mp4" "$OUT/sheet" --start 0.4 --end 1.6 \
  [--crop X,Y,W,H] [--tile-width 200] [--columns 8] [--rows 4]
```

It writes, into the output directory:

- `sheet-NN.png`: every frame in the range, tiled in time order, each labelled `#index  t=seconds  +ms since the
  previous frame`, with flagged frames framed in red. Open them with the image-reading tool.
- `motion.png`: per frame, how much the picture changed since the previous frame (bars), the interval since the
  previous frame (dots, dashes at the median) and how far the picture still is from the last frame (green line).
- `frames.tsv`: the same numbers per frame, with the region that changed.
- `frames/NNNNN.png`: the frames themselves, numbered as on the sheets.

and prints a summary: when the motion starts and stops, when it comes within 2% of its resting state for good, every
time it passes its rest and comes back out (a spring's overshoot, an oscillation), and every flagged frame:

- `gap`: an interval over 1.5x the median while the picture changes: a frame drawn late, or a stall.
- `jump`: a frame that changed over 3x as much as the frames around it: a snap, a teleport, something appearing or
  vanishing at once in the middle of smooth motion.

Use `--start`/`--end` to keep only the motion (the summary's times are the recording's own clock) and `--crop` (in
the recording's pixels) to look at one element: the distance-from-rest curve and the change bars measure whatever is
in the picture, so a crop to the element that should move is what makes them about that element. Mind the
scale: a 200 px tile of the whole 1206 px screen is 1/6 of the recording, half a pixel per point, so a 9 pt overshoot
moves 4–5 px on the sheet; crop to the element and raise `--tile-width` until the motion being judged spans pixels
enough to see.

### 4. Evaluate

- **Shape.** The green line is the motion's shape: an ease-out falls to 0 and stays; a spring falls, touches its rest
  and rises again by its overshoot before settling, once per oscillation; a step in it is a hitch. Compare the summary's
  duration, settle time and passes with what was intended. The pass percentages are of the picture's difference, not
  of the travel distance: use them to tell whether it overshoots and how many times, and read the amount off the
  frames.
- **Togetherness.** For "these move together", crop each element and compare their curves and their tiles frame by
  frame: elements that move as one stand at the same offset from rest in every frame, overshoot included. An element
  that rests while its neighbours move, arrives a frame late or overshoots alone is the defect class this catches.
- **Every flagged frame.** Open the tiles around it and say what it is. A `jump` can be legitimate (an element meant
  to appear at once); a `gap` on the simulator can be the Mac's. A gap that recurs at the same point across several
  recordings is the app's; frame pacing itself is confirmed on a device, not the simulator.
- **The frames, not just the numbers.** Read the sheets end to end for what no metric sees: clipping, a wrong z-order
  for a frame, a colour flash, text re-wrapping mid-flight, an element drawn twice during a hand-over.

Report findings with their evidence, by frame: "#23–#31 (t=0.512–0.645): the list stays at rest while the buttons
overshoot 9 pt" names something another agent or the user can open and check. A claim about an animation without frame
references has not been verified.
