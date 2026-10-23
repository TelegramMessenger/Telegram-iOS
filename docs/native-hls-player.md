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
  - `HLSBufferModel`, `HLSPartTiming`, `HLSFragmentTiming` (a part's track timing from its fMP4 boxes).
  - `HLSBandwidthStore`: the estimate per network class, shared by every player.
  - `HLSPlaybackController`: the event-driven scheduler, behind an injected `HLSPlaybackEnvironment`.
- `submodules/TelegramUniversalVideoContent/Sources/HLSNative/` — the app's environment over `TelegramEngine.resources`:
  - the playlist loader;
  - `HLSNativeEnvironment`: loads, ranges status, timers;
  - `HLSNativePartStore`: init + segment to a temp file, timed from its boxes (FFmpeg's probe only for other shapes);
  - `HLSNativePlayerSource`: the `ChunkMediaPlayerV2` `.custom` source.
- `HLSVideoNativeContentNode` — the `UniversalVideoContentNode`. `HLSVideoContent.makeContentNode` returns it, or
  `NativeVideoContent` for the base file when no quality is playable (`HLSQualitySet` nil).

## Deviations from hls.js 1.7.3

| | hls.js | here | why |
|---|---|---|---|
| D1 | every fragment samples bandwidth | only bytes that came over the network sample; a load that joined a fetch already under way does not | disk reads would inflate the estimate |
| D2 | sample to end of parsing; measured TTFB | a sample is the load's network bytes over the link's busy time charged to it: from the later of the busy period's start and the previous completed load's end (`HLSBandwidthStore`), so loads in flight together are not charged the same seconds twice; a cancelled load's time goes to the loads still running, so the estimate errs low; a fixed 100 ms TTFB in the fetch-time model | MediaBox reports bytes only as whole parts land |
| D3 | default estimate 500 kbit/s, reset per player | one estimate per network class (Wi-Fi, cellular: one class, since LTE and 5G hand over under a playing video) for the process, read and fed by every player (`HLSBandwidthStore`); after 60 s without a sample it becomes a prior of at most 4 s of weight, halved per 300 s idle; a class that has not sampled starts from what the account's other downloads measured on that network (`DownloadThroughputMeter`), with no weight, a newer seed replacing an older one | a second video should not start from scratch; Wi-Fi says nothing about cellular |
| D4 | quality from bandwidth alone | cache-aware: a level whose next segment is on disk wins over the target | play what is cached |
| D5 | master → level playlist → init ∥ segment | no master; every level's playlist at creation; when the init is not ready, init and first segment are one fetch `[0, seg0.end)` | fewer round trips to the first frame |
| D6 | an abandon falls to the rule's level | to a lower level cached at that position first | |
| D7 | `isFragmentNearlyDownloaded` divides bytes by bits/s | units fixed | |
| D8 | an aborted init can stall a re-requested fragment | a level's init is loaded once, shared and trusted | |
| D9 | 100 ms tick loop; fragment load timeouts | event-driven; timers only for retries, level cool-downs, the abandon poll and the start's playlist wait; no load timeout | a fetch waits for the server for as long as it takes, so re-issuing one only drops its parts in flight |
| D10 | fatal errors end playback | never fatal while the node lives; see "Failures" below | |
| D11 | choosing Auto flushes the buffer | Auto and the inline cap never flush | a flush shows as a stall for no gain |
| D12 | with no sample, the first auto pick uses `max(500 kbit/s, min(top, 5 Mbit/s))` | a start with no opening on disk takes the level the class's shared estimate (D3) picks by hls.js's first-level rule when that level's key is above 480 (`estimateStartAboveKey`, the owner's rule), else the preload quality; a later pick before a sample reads the shared estimate the same way | start where the preload put the bytes, or above it when the link is known |
| D13 | one fragment loads at a time | two segment loads in flight: the next starts once the newest owes the network at most `pipelineWindowBytes` (the download path's window, 6 parts of 128 KB per file) or while the current part is made; not before the first part is appended and the class has an estimate | the link idles between requests otherwise; measured in the lab, step-down +2.5% bitrate, every other profile equal |
| D14 | playback starts when media can play | after an open or a seek inside a part, while that part is the only one ahead, the clock waits until it can start with `playerMinimumBuffer` (1 s) still ahead when the next part lands at the current estimate (`startNotBefore`, handed to `ChunkMediaPlayerV2` with the parts); at most until that part lands | an open 3 s into a 5 s segment started with 2 s ahead and stalled 2.4–2.5 s on 3g (simulator), 2.25 s in the lab |

Also deliberate:
- `maxHole` is 0.2 s, because `ChunkMediaPlayerV2` plays through gaps up to 0.5 s.
- A level's data load is issued before its init load, in parallel, which D8 makes safe.
- The abandon rule never runs before the first part is appended (hls.js waits for `media.readyState`). Without that
  gate, a cold start on a slow link abandoned its first segment and loaded it again at the same level forever.
- The abandon rule chooses among all levels, as hls.js does, those without a playlist included (pinned by goldens). A
  choice without a playlist plays the nearest level that has one.
- With two loads in flight (D13):
  - The abandon check watches the oldest load still owing data, and cancels both loads when it fires.
  - A load issued behind another is judged from when the check began watching it, with the bytes it had then.
    Its time queued behind the other is no measure of its rate: judged from its issue, the lab's 3G cold start
    abandoned 720p for 360p and stalled.
  - The level choice judges a pipelined segment against the buffer as it will be once the loads in flight land,
    less the time the link still needs for what they owe.
  - Parts are made one at a time, in the order their loads finished.
  - The next segment continues the run that holds the playhead, made of buffered parts and segments in flight with
    gaps under `maxHole` joined. A segment in flight past a hole does not extend that run: the hole can come from a
    failed load or append, an abandon, or a seek that kept a load ahead of the playhead.
    - Measured from the newest segment in flight instead, the retry of a failed segment waited until the buffer was
      full: up to 60 s while the playhead stalled at the hole.
  - A load of a level whose init comes with another load in flight (D5's range from byte 0) waits for that load
    instead of fetching the init again.
- A part that a manual switch will flush when it lands does not count as buffered: the new level loads from the
  playhead.

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
  (FetchV2 on MtProtoKit: 128 KB parts, at most 6 in flight per file, 12 requests per datacenter shared by every
  download), so a live load on a slow link can be silent for a long time.
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
  chat preload, the inline gate, the player's start and the node's inline cap all use it. The start takes it when no
  opening is on disk and the class's estimate picks 480p or lower, or there is no estimate (D12).
  - The bubble thumbnail uses it only when the chat preload runs for that bubble (auto-download on). Otherwise it keeps
    PhotoResources' cheaper rule (longer side ≥ 600).
  - Scrubbing previews keep the lowest quality.
- **The chat prefetchers skip an HLS video's original file** (`PrefetchManager`, `InChatPrefetchManager`). The
  player never reads it, yet they fetched its first 4 s (`preloadVideoResource`), or all of it under auto-download:
  measured 2.5 MB of the 3-hour test video's original, and 21 MB of a shorter one's, on opening Saved Messages.
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
- **A gallery open starts the controller at its position** (`HLSVideoContent.startTimestamp`: the tapped timecode, the
  stored position, a forwarded timestamp, by the gallery's own precedence). Before it, the controller started at 0
  and heard of the position only from the gallery's seek about 50 ms later, after the opening had been appended or
  its load issued. The node seeks the player too: its position reports would otherwise take the controller back to 0.
- **The watched video goes ahead in the download queue while its buffer is short.** While playback with sound (the
  gallery) is playing or buffering, the node pushes download priority for its quality files when less than 10 s is
  buffered and drops it above 20 s or on pause; inline autoplay never does. A priority held for the whole playback
  would hold back every other download for as long as a slow link keeps the buffer from filling.
- **Within one file the player's ranges go first.** FetchV2 takes a file's parts from its highest priority bucket
  (the player loads at `.elevated`, the chat preload of the same file at `.default`), and a range asked for at two
  priorities is fetched once; it used to share part slots round-robin, a third to the player.
- **A first video starts from the account's other downloads** (D3): FetchV2 times every media part with the engine's
  send-to-receive duration into `DownloadThroughputMeter` (bits over the union of the parts' intervals, the last
  120 s, nil below 512 KB); a class that has not sampled is seeded from it, with no weight, again by every new
  player. Small files measure round
  trips, so the seed errs low. Under `-debugNetworkProfile` the shaper reports a held response's time as the shaped
  link's, or the meter would measure the Mac's network.
- **A part's timing is read from its boxes** (`HLSFragmentTiming`): per track, the first sample's presentation time
  less the edit list's media time, and the end of the decode times, as FFmpeg's probe reports them (its start is the
  first packet's, `index_entries[0]`, not the earliest: open-GOP leading pictures present before it). Only the shape
  Telegram's segments come in is read (one `moof`, one `traf` per track, no edit list or one plain entry on the video
  track, no negative composition offset, an audio edit list only for plain AAC, below); anything else goes to FFmpeg's
  probe as before, and so do bytes no honest segment holds (a size past its box, a time that overflows, more than
  `maximumSampleCount` samples): segment bytes come from the network, and the parser must never trap or walk an
  unbounded count. Matched to the
  microsecond on 26 real 720p and 1080p segments of the test video (against ffprobe; 6 of them against the vendored
  FFmpeg's probe), on ffmpeg-CLI fixtures, and on 64 real parts cut from the simulator's cache of 45 quality files
  (AV1 29, H.264 28, HEVC 7; ffprobe 9.0.2, start and `extractFFMpegMediaInfo`'s `duration − start`).
- **AAC priming is read for plain AAC only.** About a third of the quality files (15 of 45 in the simulator's cache,
  AV1 and H.264 ones) carry an audio edit list marking the encoder's priming (media time 2112 or 1024). FFmpeg does not
  move the timeline for it: mov sets the media time as samples to skip (`start_pad`, `skip_samples`), and the stream's
  start adds them back at the codec's sample rate (`update_initial_timestamps`). With plain AAC-LC at the track's
  timescale the two cancel, so the start is the first sample's decode time and the length the sum of its durations;
  the parser reads the mp4a entry's esds (MPEG-4 audio, an AudioSpecificConfig of object type 2, a table rate equal to
  the timescale, channels 1–7, no core coder or extension flag, and nothing after it but a sync extension saying SBR
  is absent) and leaves everything else to the probe: HE-AAC (FFmpeg's rate can then be twice the core's), any other
  config, a rate that differs from the timescale. All 34 primed parts of that cache (AAC-LC 44.1 kHz, 2- and 5-byte
  configs) and the `fragment-edit` fixture match: 74 of 74 cached parts with the parser reading them all.
- **A seek inside a part decodes from the keyframe before it** (`ChunkMediaPlayerV2`, temp-file parts only): the
  part's readers open with a direct seek to the target, and the video decoder skips non-reference frames
  (`AVDISCARD_NONREF`) until the first packet at or after the target, which no frame at or after the target precedes
  in decode order. A real 1080p segment held 2 keyframes and 48 non-reference frames of 98. FFmpeg's mov seek
  searches decode times (`mov_seek_stream`), so a target in the decoder delay before a keyframe (at or after its
  decode time, before its presentation) lands on it, after frames of the previous group that present at or after the
  target; the reader reads the first packet after the seek and, when that keyframe presents after the target, seeks
  again to just before its decode time. On the fixture whose video edit list takes the delay off, the seek landed
  early enough by itself (mov subtracts the edit list's media time again before searching); on the one without, six
  targets of 150 lost frames, and the first frame came 40–120 ms late. Of the simulator's cached quality files, the
  HEVC ones and most H.264 ones carry no video edit list.
- **The clock waits after an open or a seek inside a part (D14)** while the part holding the position is the only one
  ahead and leaves less than a whole segment: `HLSPlaybackController.startNotBefore` is the earliest moment the clock
  can start and still have 1 s ahead when the next part lands (in flight: what it still owes, plus the first byte if
  nothing has arrived; not yet issued: the next segment at the part's level, as the level choice charges it). The node
  hands it to `ChunkMediaPlayerV2` with the parts, which holds its clock until then only before its first move since a
  seek; a run that reaches the video's end is never held. The controller reports an appended part after it has chosen
  the next load, so the gate charges that load. Without it, a cold open at a timestamp near a segment's end started with
  1–2 s ahead, and hls.js's level choice (faithful here: its first pass fails, its second tolerates `min(segment, 4 s)`
  of starvation) kept 720p, so the clock stalled until the next part landed. Lab, 3g, the test video's ladder: an open
  2 s before a segment's end starts at 5.60 s with no stall (was 3.30 s and a 2.25 s stall), 1 s before at 6.55 s (was
  3.30 s and 3.20 s); on LTE only the open 1 s before the end changes (1.10 s, was 0.55 s and a 0.5 s stall); every
  open at a segment's start is unchanged. A prediction a few hundredths short can leave a blip under the player's 0.3 s
  spinner (3g, 3 s before the end: 0.05 s). The player requests no media while its clock is held, so the first frame
  waits too: on the simulator under 3g, a cold open at 1583 s (3 s into segment 316) showed its first frame at 7.9 s
  instead of 4.7 s and stalled 289 ms instead of 2,515 ms (the next part came 0.35 s after the prediction: other
  downloads slowed the shaped link after the estimate was taken). Showing that frame while the clock is held is not
  built.
- **A part's two readers probe only their own stream** (temp-file parts only): the other media type is discarded
  before `avformat_find_stream_info`, which otherwise decodes H.264 in software for the audio reader too.

## Logs

- `HLSNative`, per video: when each playlist arrives and when the disk state is known, the start level and why, each
  sample, level choices, failures, cool-downs and abandons.
- `HLSStart`, once per node at its first frame:
  `HLSStart file=… engine=native initToPlayMs=… playToFirstFrameMs=… initToFirstFrameMs=… startQuality=<key of the
  first part> firstSegment=<disk|network> sound=<0|1> startedMs=… firstLoadMs=… firstLoadDoneMs=… firstAppendMs=…
  firstAppendDoneMs=…`. The last five are ms from the node's creation on the controller's clock, -1 when the step had
  not happened by the first frame (a start from disk issues its first load after it).
- `HLSSession`, once per node when it goes away:
  `HLSSession file=… network=<class> stalls=… stallMs=… seekWaits=… seekWaitMs=… playedMs=… levels=<key>:<s>,…
  switches=… networkBytes=… diskBytes=… abandons=… estimate=<bps|none>`. A stall is buffering while play is requested
  after the first frame; buffering after a seek, until playback plays again, is a seek wait (`HLSPlaybackStats`).
- The inline gate logs a playlist still missing after 10 s, and a gate that ended without a range.
- `DebugNetworkShaper` (debug builds launched with `-debugNetworkProfile`): the profile, and every 2 s the responses
  it held and the mean hold.

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

## Slow networks (2026-10-22): the shared estimate and two loads in flight

**Lab** (`HLSPlaybackLabTests`, 120 s video, ladder 0.35/0.6/1.1/2.2 Mbit/s; start s, stalls, mean kbit/s):

| profile | cache | before | after |
|---|---|---|---|
| wifi, lte | cold | 0.20 or 0.70, 0, 2153 | same |
| wifi, lte | 10 s preloaded | 0.05, 0, 2061 | same |
| poor-lte, 3g | cold | 2.05 or 4.05, 0, 1100 | same |
| poor-lte, 3g | 10 s preloaded | 0.05, 0, 1100 | same |
| step-down | cold | 0.70, 0, 1869 | 0.70, 0, 1915 |
| step-down | 10 s preloaded | 0.05, 0, 1775 | 0.05, 0, 1821 |

The ladder's steps are coarse, so a better estimate changes picks only where the link moves (step-down). No profile
stalls or starts later. The lab caught the abandon on a load queued behind another, which stalled 3g cold for 1.5 s.
It also caught two level-choice regressions, each later fixed:
- a second segment picked by the start rule before the first sample (wifi and lte cold, −46 kbit/s);
- a pipelined segment judged on the buffer without the segment ahead of it (3g cold, 1100 → 783 kbit/s).

**A second video starts from the estimate** (D12). The lab, a second run on the same store right after the first
(start s, mean kbit/s; the preload-quality start → the estimate's):

| profile | preload-quality start | estimate's start |
|---|---|---|
| wifi | 0.20, 2153 | 0.30, 2200 (1080p) |
| lte | 0.70, 2153 | 1.25, 2200 (1080p) |
| poor-lte, 3g, step-down | 2.05, 4.05 or 0.70 | same (the estimate picks 720p or lower) |

The gain is the first segment at 1080p instead of 720p, which ABR leaves after one segment anyway; the cost is that
segment's extra bytes before the first frame. hls.js's first-level rule accepts a first load of up to
`maxStarvationDelay` (4 s).

**Simulator** (`-debugNetworkProfile`, the 3:39:25 interview in Saved Messages opened at 0:00 from its caption's
timestamp link, sound on, its playlists and quality files deleted before each run; this video's ladder is
0.53/0.87/1.12 Mbit/s; every start was from the 720p opening the bubble thumbnail fetched):

| profile | before: first frame, stalls, levels (s), estimate | after |
|---|---|---|
| lte | 127 ms, 0, 720:12 1080:78, 8.39 Mbit/s | 167 ms, 0, 720:12 1080:52, 8.48 Mbit/s |
| poor-lte | 147 ms, 0, 720:12 1080:52, 2.64 Mbit/s | 160 ms, 0, 720:12 1080:52, 2.64 Mbit/s |
| 3g | 185 ms, 0, 720:15 480:49, 1.22 Mbit/s | 139 ms, 0, 720:38 480:25, 1.29 Mbit/s |

- **Starts are unchanged.** They are disk starts either way, and the first frames are within run-to-run noise.
- **On 3g the time at 720p more than doubled**, 15 s to 38 s of 64.
- **The estimate moves on 3g only:** 1.22 before, then 1.48 and 1.29 Mbit/s in two runs after, on a 1.5 Mbit/s link.
  On 3g the round trip is a large part of a segment's load. Elsewhere the buffer is full most of the time, and a
  single segment topping it up still pays its round trip.
- **Quality switches on 3g:** the first build after the change showed six switches a minute, 480/720 alternating.
  That was hls.js's hysteresis judged against a part two segments back. With the fix
  (`testPipelinedPicksDoNotAlternateBetweenTwoLevels`) there were two.
- `step-down` was not run on the simulator. The shaper's steps count from its first use (the process's first media
  request), so the drop does not line up with playback.

## The start path (2026-10-23, iPhone Air, debug build, Wi-Fi)

Measured with temporary timing logs in the part store and `ChunkMediaPlayerV2`, on resumed and timestamp opens of
two videos from disk:

| open | first frame | hidden frames decoded first | part probe | readers (video + audio) |
|---|---|---|---|---|
| resumed at 1:16:34, first after launch | 591 ms | 114 (342 ms) | 78 ms | 32 + 43 ms |
| reopened at 1:17:02 | 159 ms | 14 (32 ms) | ~25 ms | 21 + 22 ms |
| other video, resumed at 0:59 | 238 ms | 62 (144 ms) | ~25 ms | 22 + 21 ms |

- **The first frame is on screen 1–2 ms after the first frame at or after the target is enqueued.** Everything before
  it is getting that frame decoded.
- **Most of a resumed or timestamp open is hidden frames:** the part starts at its segment's keyframe, and every frame
  up to the target was decoded (about 3 ms each with VideoToolbox) only to be hidden. Hence the keyframe seek and the
  non-reference skip above.
- **The part store's FFmpeg probe** took 15–78 ms a part (the first part's is on the critical path); hence the box
  timing. Each reader's probe took 20–43 ms; hence the probe of only its own stream.
- The first activation of the audio session took 62 ms, off the video's path.
- The simulator showed the same shape at about twice the cost (software decoding).

After this branch (2026-10-24, same device and build type, the same timing logs), on the same two videos a little
further on, and two others from 0:

| open | first frame | hidden frames decoded first | part timing | readers (video + audio) |
|---|---|---|---|---|
| other video, resumed at 1:05, first after launch | 181 ms | 7 | boxes, 0.1–0.2 ms | 72 + 4 ms |
| other video, reopened at 1:20 | 95 ms | 6 | boxes | 30 + 5 ms |
| long video, resumed at 1:17:08 | 132 ms | 13 | boxes | 23 + 1 ms |
| two videos from 0 (AAC priming, so probed) | 69, 57 ms | 0 | FFmpeg's probe | 30 + 1, 16 + 2 ms |

- **First frame, warm:** 159 → 132 ms (long video), 238 → 95 ms (other video). First after launch: 591 ms before
  (long video, 114 hidden frames), 181 ms now (other video, 7 hidden frames); not the same video, so read it as the
  hidden frames gone rather than a like-for-like number.
- **Hidden frames** are now the reference frames between the keyframe and the target: 6–13 against 14–114, and they
  are most of what is left of a resumed open (about 50 ms from the readers to the first frame, against 10 ms from 0).
- **Part timing** from the boxes takes 0.1–0.7 ms a part against the probe's 15–78 ms, and the audio reader opens in
  1–5 ms against 21–43 ms. The first video reader after launch took 72 ms against 32 ms; with the audio reader the
  first part's readers took the same 75 ms in both runs, one sample each.

## Considered and not built (2026-10-23)

- **Fetching the opening alongside the playlists** (a guessed `[0, guess)` range at start): position-0 openings are
  already on disk from the bubble thumbnail or the chat preload (every `HLSStart` from 0 on the simulator was
  `firstSegment=disk`), and resumed opens now start at their own position.
- **A resume threshold above 1.0 s after a stall:** parts are whole 5 s segments, so the playable duration grows by a
  part at a time and a 1.0 s threshold cannot stutter-cycle.
- **Caching refreshed file references:** each new fetch of a file starts from its caller's reference, so after it
  expires every later segment load would pay a failed part and a refresh; no session in hand showed it. FetchV2 now
  logs "refreshing file reference again in this process" when it happens.
- **Keeping readers across a seek inside the current part:** the decode from the keyframe is the cost, and that is
  covered by the keyframe seek; the reader probes it would save are now small.

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
  - Every one checks the invariants:
    - no range fetched twice from the network;
    - no disk read sampled;
    - no load of a range already on disk;
    - every sample matches one completed network load;
    - the samples are never charged more time than the network loads spanned;
    - no segment is loaded while its time span is already buffered, at any level.
  - The tests that pin load order, ranges and retry timings run one segment load at a time
    (`ControllerHarness.oneLoadAtATime`), the order they were written for. `HLSPlaybackControllerPipelineTests` and the
    lab run the production configuration (two in flight, D13).
- **The playback lab** (`HLSPlaybackLabTests`, `Tests/Support/PlaybackLab.swift`):
  - The controller runs over one shared link (`SimulatedLink`: 128 KB parts, 6 in flight per level and 12 in all,
    each landing a round trip after it was sent or once the link is done with the parts before it).
  - The player follows `ChunkMediaPlayerV2`'s rules: it plays while 1.0 s is buffered and stalls otherwise.
  - Five profiles, cold and with a 10 s preload: wifi, lte, poor-lte, 3g and step-down. They are the same as
    `-debugNetworkProfile`'s.
  - `testNoProfileIsWorseThanTheBaseline` fails a change that stalls more or starts later on any of them than
    `LabBaseline`.
    - The profiles are steady links with no failure and no seek, so the gate sees stall regressions on step-down
      only. It could not have caught the hole a failed load left with two loads in flight.
    - The failure, seek and abandon paths are in `HLSPlaybackControllerPipelineTests`.
  - `testBaselineTable` prints the table: run with `--test_output=all`.
- Goldens: `Tests/HLSJSGoldens.swift` holds values computed by hls.js 1.7.3's own TypeScript.
  - Regenerate with `sh submodules/HLSPlayback/Tools/hlsjs-goldens/generate.sh`; see its README.
  - Never edit the file by hand.
- `HLSFragmentTimingTests` (host) builds parts box by box: the timing, the shapes left to FFmpeg, truncation.
- `Make.py test --target //submodules/MediaPlayer:UniversalMediaPlayerTests`: `ChunkMediaPlayerV2`'s custom source;
  `HLSFragmentTimingParityTests`, the box timing against the vendored FFmpeg's probe; `FFMpegFileReaderStartTests` and
  `FFMpegFileReaderProbeTests`, the readers of a part. Their fixtures (`Tests/Fixtures/`) come from the ffmpeg CLI
  (`testsrc2`, a sine tone); the commands are in the test files. Never commit a real segment.

## Licence

`HLSPlayback` is ported from hls.js, © Dailymotion and the hls.js contributors, Apache License 2.0. The repository
keeps no list of third-party licences outside `third-party/`, so each ported file's header is the record.
