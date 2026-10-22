# Native HLS player

Since October 2026, HLS videos (a message video with alternative qualities) play through a Swift port of the parts
of hls.js 1.7.3 our streams use, fed to `ChunkMediaPlayerV2`. It replaced hls.js 1.5.15 running in JavaScriptCore
behind emulated MSE objects and a local HLS server, which is deleted. This document is the record: what each piece
does, where it deliberately differs from hls.js, and the facts the code depends on that it cannot show.

## Pieces

- `submodules/HLSPlayback` — Foundation only, no Postbox, no UIKit:
  - `HLSMediaPlaylist`: the media-playlist parser, used by every HLS path in the app.
  - `HLSBandwidthEstimator`: hls.js's EWMA estimator, pinned against goldens.
  - `HLSLevels` and `HLSAbr`: levels, the preload-quality rule, the start rule, `findBestLevel`, `nextAutoLevel` and
    the abandon rule.
  - `HLSBufferModel`, `HLSPartTiming`.
  - `HLSPlaybackController`: the event-driven scheduler, behind an injected `HLSPlaybackEnvironment`.
- `submodules/TelegramUniversalVideoContent/Sources/HLSNative/` — the app's environment over `TelegramEngine.resources`:
  - the playlist loader;
  - `HLSNativeEnvironment`: loads, ranges status, timers;
  - `HLSNativePartStore`: init + segment to a temp file, probed with FFmpeg;
  - `HLSNativePlayerSource`: the `ChunkMediaPlayerV2` `.custom` source.
- `HLSVideoNativeContentNode` — the `UniversalVideoContentNode`. `HLSVideoContent.makeContentNode` returns it, or
  `NativeVideoContent` for the base file when no quality is playable (`HLSQualitySet` nil).

## Deviations from hls.js 1.7.3

| | hls.js | here | why |
|---|---|---|---|
| D1 | every fragment samples bandwidth | only bytes that came over the network sample; a load that joined a fetch already under way does not | disk reads would inflate the estimate |
| D2 | sample to end of parsing; measured TTFB | sample over the whole request; a fixed 100 ms TTFB in the fetch-time model | MediaBox reports bytes only as whole parts land |
| D3 | default estimate 500 kbit/s, reset per player | the previous player's estimate seeds the next, as a value without weight (`HLSBandwidthSeed`) | a second video should not start from scratch |
| D4 | quality from bandwidth alone | cache-aware: a level whose next segment is on disk wins over the target | play what is cached |
| D5 | master → level playlist → init ∥ segment | no master; every level's playlist at creation; when the init is not ready, init and first segment are one fetch `[0, seg0.end)` | fewer round trips to the first frame |
| D6 | an abandon falls to the rule's level | to a lower level cached at that position first | |
| D7 | `isFragmentNearlyDownloaded` divides bytes by bits/s | units fixed | |
| D8 | an aborted init can stall a re-requested fragment | a level's init is loaded once, shared and trusted | |
| D9 | 100 ms tick loop; fragment load timeouts | event-driven; timers only for retries, level cool-downs, the abandon poll and the start's playlist wait; no load timeout | a fetch waits for the server for as long as it takes, so re-issuing one only drops its parts in flight |
| D10 | fatal errors end playback | never fatal while the node lives; see "Failures" below | |
| D11 | choosing Auto flushes the buffer | Auto and the inline cap never flush | a flush shows as a stall for no gain |
| D12 | with no sample, the first auto pick uses `max(500 kbit/s, min(top, 5 Mbit/s))` | the seed, else the preload quality | start where the preload put the bytes |

Also deliberate:
- `maxHole` is 0.2 s, because `ChunkMediaPlayerV2` plays through gaps up to 0.5 s.
- A level's data load is issued before its init load, in parallel, which D8 makes safe.
- The abandon rule never runs before the first part is appended (hls.js waits for `media.readyState`). Without that
  gate, a cold start on a slow link abandoned its first segment and loaded it again at the same level forever.
- The abandon rule chooses among all levels, as hls.js does, those without a playlist included (pinned by goldens). A
  choice without a playlist plays the nearest level that has one.

## Failures (D10)

No failure is terminal: nothing stops loading a video, a playlist or a range because a fetch failed. It is tried
again, with a growing delay, for as long as it is wanted. A fetch has no timeout of its own: it waits for the server for
as long as it takes, days if need be. Only a fatal error ends one, and a range fetch reports that as completion with
bytes still missing.

- Retries wait 1, 2, 4, 8 s, then 8 s for ever. The clock runs only while the account's network is connected
  (`ConnectedTimer`).
- A level with 6 failures in a row is errored for a cool-down: 30 s of connected time, doubled each time it errors
  again, at most 5 min. Then it is tried again, and one more failure errors it again. A load at the level resets both.
  While a level is errored, the next pick takes a level without errors that is cached at that position, else the
  nearest lower one with a playlist.
- A level whose playlist the loader rejected (it does not parse, or names another file: content, not the network) is
  errored for good and left out of the quality menu (unless every level is); a manual pick of it plays the nearest
  level with a playlist.
- A load is never issued again for receiving nothing, a segment's or an init's: it waits for the server. Only a
  failure (then a retry) or the abandon rule ends one early. MediaBox reports progress only as whole parts land
  (files over 512 KB fetch 8 parallel 512 KB parts), so a live load on a slow link can be silent for a long time.
- The start waits for every level's playlist, or for word that it is not on disk.
  - The preload level's own playlist is waited for 5 s of connected time once another level's has arrived; then the
    start takes the nearest level with a playlist.
- A failed playlist fetch is started again after 2, 4, 6 … at most 30 s, by all three fetchers: the node's loader,
  the chat preload's `minimizedHLSQualityPreloadData` (also the inline gate's) and the bubble thumbnail's
  (`PhotoResources`).
- The chat preload's and the thumbnail's range fetches go through `fetchedResourceRangeUntilOnDisk` (`PhotoResources`):
  while the range has bytes missing when its fetch ends, the fetch is started again with the same backoff.
- A quality change cuts a pending retry short (hls.js's `immediateLevelSwitch`); a seek does not.

## Facts the code depends on

- **Levels are sorted by height** (`HLSLevels.sorted`), and every level index in the controller, the environment and
  the node is into that order. A level's key is the quality key, `min(width, height)`.
- **The preload quality is one rule** (`HLSLevels.preloadQualityKey`: the smallest key ≥ 600, else the smallest). The
  chat preload, the inline gate, the player's start and the node's inline cap all use it.
  - The bubble thumbnail uses it only when the chat preload runs for that bubble (auto-download on). Otherwise it keeps
    PhotoResources' cheaper rule (longer side ≥ 600).
  - Scrubbing previews keep the lowest quality.
- **Disk reads never sample.** The controller asks the environment for `missingBytes` before a load, and samples only
  what the network delivered.
- **Fetches go through MediaBox's own file context** (`fetch`, `rangeData`, `resourceRangesStatus`, `status`), never
  a private one. That is how the player joins the chat preload's in-flight bytes instead of fetching them again.
- **A segment load whose fetch completed with bytes still missing has failed.** MediaBox turns a range fetch's error
  into completion. The last part of a completed fetch reaches the ranges status in the same MediaBox data-queue task
  that completes the fetch, ahead of the completion, and both reach the main queue in that order, so the check needs
  no margin; the 1 s it waits only covers a busy main queue.
- **The parser accepts what the old regexes did**: no `EXT-X-ENDLIST`, no `EXT-X-TARGETDURATION` (derived from the
  longest segment), and an `EXT-X-MAP` without a byte range (or none) is everything before the first segment.
- **A part is the level's init plus one segment, never the bytes between them.** Those bytes hold a `sidx` box, which
  makes FFmpeg report the whole video's duration for a video-only file. The D5 range is a load range only.
- **A part runs from its audio start to the later of its two tracks' ends** (`HLSPartTiming`).
  - A stream's audio can stop before its video. Measured: 0.33 s of audio in the next-to-last 5 s segment of one video,
    and none in the last.
  - Timing parts by the audio alone turned the rest of that segment into a hole nothing filled: a video resumed near its
    end showed no frame. hls.js only crossed it because its gap controller seeks over holes.
- **`captureProtected` reaches `HLSVideoContent` from both callers.** The inline node moves to the gallery, so the
  chat bubble passes the union of its own expression and the gallery's.
  - The bubble's expression includes `message.paidContent != nil`: the bubble builds the inline node on a relayout
    where its own paid-media flag is not computed.
- **`HLSNativePlayerSource` hops with `DispatchQueue.main.async`**, not `Queue.mainQueue().async`, which runs inline
  on main: the player calls it from inside its own state update.
- **Part temp files** are disposed a main-queue turn after the next parts list is built, by which time the player has
  that list.

## Logs

- `HLSNative`, per video: when each playlist arrives and when the disk state is known, the start level and why, each
  sample, level choices, failures, cool-downs and abandons.
- `HLSStart`, once per node at its first frame:
  `HLSStart file=… engine=native initToPlayMs=… playToFirstFrameMs=… initToFirstFrameMs=… startQuality=<key of the
  first part> firstSegment=<disk|network> sound=<0|1>`.
- The inline gate logs a playlist still missing after 10 s, and a gate that ended without a range.

## Measurements (2026-10-22, iPhone 18 Pro simulator, Mac Wi-Fi)

`playToFirstFrameMs` from the `HLSStart` line, on five videos forwarded to Saved Messages (0:55 to 3:39:25), opened
from their bubbles in the gallery with sound.
- (a) Uncached: auto-download off, cache cleared, each video opened once.
- (b) Preloaded: auto-download on, cache cleared, each bubble 10 s in view, then opened.
- (c) Reopened: played about 20 s, closed, reopened.

| | JS (hls.js 1.5.15) | native | native start |
|---|---|---|---|
| (a) uncached, median | 657 | 179 | 4 of 5 from disk (the thumbnail's first-segment fetch), at 480p or 720p |
| (b) preloaded, median | 1,003 | 62 | every start from disk; 720p, or 1080p where a 1080p opening was cached |
| (c) reopened, median | 557 | 402 | from disk; 1,031 and 1,194 ms where the cached opening was 1080p |

Caveats:
- **Stored positions.** The gallery stores a video's position on close (when more than 5 s from either end), so a
  later run resumes where the previous one stopped.
  - The JS column ran first, from whatever positions the videos had.
  - The native column ran later, from 0:00 (each video dragged to the start and closed under 5 s first).
  - A second JS round from 0:00 was not completed. The JS player twice failed to start a video at all after a cache
    clear, frozen on its first frame with `TypeError: … window.hlsPlayer_instances[0].playerNotifySeekedOnNextStatusUpdate`
    in the log, and an app restart did not clear it. Separately, an Unreal Engine bake loaded the Mac for hours.
- **Uncached native starts below the preload quality by design.** With auto-download off, the bubble thumbnail
  fetches the first segment of PhotoResources' quality (longer side ≥ 600, often 480p). The cache-aware start (D4)
  then plays that cached opening rather than fetching 720p, so the first seconds show the thumbnail's quality before
  ABR climbs.
- **A cached 1080p opening costs about 1 s from append to first frame**, against 170–400 ms for 480p and 720p parts.
  The start rule picks the highest cached level within the cap.

## Simulator checks (2026-10-22)

- **Inline autoplay:** bubbles start muted at the preload quality, from disk once the chat preload has run. They loop
  at the end without a stall.
- **Bubble to gallery:** the gallery takes over the playing node. There is no new player, no black frame, and the
  inline frame grows into the gallery. The gallery then opens the video from 0:00 (`seek: .start`, its rule for every
  video).
- **Quality menu:**
  - A manual level loads that level from the playhead.
  - Auto continues from the buffer without a flush.
  - The menu shows the level playing under "Auto".
- **Seeking:**
  - ±15 s and the scrubber move playback and the picture while playing.
  - While paused, the label moves but the picture is drawn only on play (`ChunkMediaPlayerV2`; not compared with
    the old path).
  - Resumed near its end, a video whose audio stops early plays to the end (`HLSPartTiming`).
- **Scrubbing previews** show the right frames.
- **Background:** playback continues while the app is in the background. The simulator could not be locked, so the
  lock-screen case is unchecked.
- **Not checkable on the simulator:**
  - PiP: AVKit reports `isPictureInPictureSupported NO`.
  - Capture protection: the test account has no protected content that could be opened.

  Check both on a device:
  - a protected HLS video in the gallery, opened directly and from a playing bubble, against a protected non-HLS video;
  - PiP from the gallery.

## Tests

- Host: `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/HLSPlayback:HLSPlaybackTests`.
  - The controller tests run over a simulated clock, network and disk (`Tests/Support/SimulatedEnvironment.swift`).
  - Every one checks the invariants: no range fetched twice from the network, no disk read sampled, no load of a range
    already on disk, and every sample matches one completed network load.
- Goldens: `Tests/HLSJSGoldens.swift` holds values computed by hls.js 1.7.3's own TypeScript.
  - Regenerate with `sh submodules/HLSPlayback/Tools/hlsjs-goldens/generate.sh`; see its README.
  - Never edit the file by hand.
- `ChunkMediaPlayerV2`'s custom source: `Make.py test --target //submodules/MediaPlayer:UniversalMediaPlayerTests`.

## Licence

`HLSPlayback` is ported from hls.js, © Dailymotion and the hls.js contributors, Apache License 2.0. The repository
keeps no list of third-party licences outside `third-party/`, so each ported file's header is the record.
