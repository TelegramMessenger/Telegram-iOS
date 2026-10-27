# Native HLS player (`HLSPlayback`)

HLS videos play through `submodules/HLSPlayback`, a Foundation-only Swift port of the parts of hls.js 1.7.3 our streams
use: the playlist parser, the EWMA estimator, ABR with abandon, a buffer model and an event-driven
`HLSPlaybackController`. The app's environment (`TelegramUniversalVideoContent/Sources/HLSNative/`) feeds
`ChunkMediaPlayerV2` through its `.custom` source, and `HLSVideoNativeContentNode` is the content node. The deviations
from hls.js (D1–D14), the failure policy, the logs and the measurements are in
[`docs/native-hls-player.md`](../../docs/native-hls-player.md). None of this shows up as a build error:

- **Levels are sorted by height** (`HLSLevels.sorted`), and every level index is into that order.
- **Disk reads never sample** the bandwidth estimate. Loads go through MediaBox's own file context
  (`TelegramEngine.resources`), never a private one, so the player joins the chat preload's in-flight fetch.
- **One preload-quality rule** (`HLSLevels.preloadQualityKey`) serves the chat preload, the inline gate, the player's
  start and the inline cap. The bubble thumbnail follows it only when the chat preload runs. A start with no opening
  on disk takes the level the class's estimate picks instead, when that level is above 480p (D12, owner decision).
- **The chat prefetchers skip an HLS video's original file** (`PrefetchManager`, `InChatPrefetchManager`;
  `NativeVideoContent.isHLSVideo`): the player never reads it. A new prefetcher of video files must skip it too.
- **A part is the level's init plus one segment**, never the bytes between them (a `sidx` there makes FFmpeg report the
  whole video's duration). A part ends at the later of its tracks' ends (`HLSPartTiming`): a stream's audio can stop
  before its video, and a part cut at the audio's end leaves a hole the player waits at.
- **`HLSVideoContent` takes `captureProtected` from both callers.** The inline node moves to the gallery, so the bubble
  passes the gallery's conditions too, `message.paidContent != nil` included.
- **The abandon rule never runs before the first part is appended**, as hls.js waits for `media.readyState`; without
  that, a slow cold start abandons and reloads its first segment forever.
- **One bandwidth estimate per network class for the process** (`HLSBandwidthStore`, D3): every player reads and feeds
  it, and the node maps `Account.networkType` to the class (Wi-Fi, or cellular as one class: LTE and 5G hand over under a
  playing video, and a class change drops the samples in flight). A sample is charged the link's busy time, so loads in
  flight together, of one player or several, are not charged the same seconds twice. A load that began on another
  class is not sampled.
- **Two segment loads in flight** (D13), never before the first part is appended and the class has an estimate (until
  then the next level would come from the start rule, not the link). A load issued behind another is judged by the
  abandon rule from when the rule began watching it, not from its issue, or its time queued behind the other reads as a
  slow link and it is abandoned. hls.js's switch hysteresis is judged against the level last chosen, not the last
  appended part (two segments back), or picks alternate between two levels. Changes to the scheduler go through the
  playback lab (`HLSPlaybackLabTests`): no profile may stall more or start later than `LabBaseline`.
- **The clock waits for `startNotBefore` after an open or a seek inside a part** (D14): while that part is the only one
  ahead, the controller predicts when the next part lands and the node hands the moment to `ChunkMediaPlayerV2` with
  the parts, which holds its clock until then before its first move since a seek. An appended part is reported only
  after the next load is chosen: the node reads the gate in that report, and reported earlier the gate would charge a
  guess at the part's level instead of the load the scheduler chose (480p instead of 720p, landing 1.25 s apart, in the lab).
  Keep the lab's player model (`PlaybackLab`) taking the gate in the buffer-change callback as the node does. The held
  clock also holds the first frame (no media is requested while buffering). The lab opens mid-segment through `PlaybackLab(startPosition:)` on
  `LabStreams.testVideoLadder` (three levels, no 360p rung, whose fast segments would hide the stall).
- **A caller that knows where playback starts passes it** (`HLSVideoContent.startTimestamp`; the gallery passes the
  timecode, stored position or forwarded timestamp by its own precedence). Without it the controller starts at 0 and
  loads or appends the opening before the seek arrives.
- **Queue priority only while the watched video is short of buffer** (sound-on playback, under 10 s buffered, off
  above 20 s or on pause; `pushPriorityDownload` on the quality files). Holding it for the whole playback starves
  every other download on a slow link: the owner's rule is that the player must not.
- **A first video is seeded from the account's other downloads** (`TelegramEngine.resources.downloadThroughputEstimate`
  into `HLSBandwidthStore.seedPrior`, weightless, only for a class that has not sampled; each new player seeds
  again, replacing an older seed).
- **A part's timing comes from its boxes** (`HLSFragmentTiming`), FFmpeg's probe only when they are in another shape.
  It must give what FFmpeg's probe gives: `HLSFragmentTimingParityTests` (UniversalMediaPlayer) pins that on
  ffmpeg-CLI fixtures. A change of the server's segment format makes parts fall back to the probe, slower but right;
  check a new format against `extractFFMpegMediaInfo` before widening what the parser accepts. Its bytes come from the
  network, so it never traps or walks an unbounded count: every size and time is checked for overflow and the samples
  it reads are bounded (`maximumSampleCount`), and any such input goes to FFmpeg (`testCorruptedBoxesNeverTrap` and
  the overflow tests in `HLSFragmentTimingTests`). An audio edit list (AAC priming) is read only for plain AAC-LC
  at the track's timescale (`plainAACSampleRate`): FFmpeg adds the skipped priming back at the codec's sample rate,
  which for HE-AAC can differ from the timescale, so any other config stays FFmpeg's.
- **`ChunkMediaPlayerV2`'s temp-file readers (HLS parts only)** open a part that holds a seek target at the keyframe
  before it and skip non-reference frames until the target, and probe only their own stream. Both are scoped by the
  content kind; other players' readers are unchanged. FFmpeg's mov seek searches decode times, so after it the video
  reader checks the keyframe it landed on and seeks once more when that keyframe presents after the target; without
  it a target in the decoder delay before a keyframe loses the previous group's frames that present after the target
  (`testNoFrameAtOrAfterTheTargetIsLostWhereverTheTargetFalls`).
- **No network failure is terminal** (owner decision). A fetch waits for the server for as long as it takes; only a
  fatal error ends one, and a range fetch reports that as completion, so check the bytes
  (`fetchedResourceRangeUntilOnDisk`). Every HLS fetch retries with backoff, and a failing level is avoided for a
  cool-down, never for good. Only content (a rejected playlist) is final.
- **A slow network on the simulator:** launch a debug build with `-debugNetworkProfile <wifi|lte|poor-lte|3g|step-down>`
  (or `<bitsPerSecond>,<roundTripMs>`; `xcrun simctl launch <udid> ph.telegra.Telegraph -debugNetworkProfile 3g`).
  `DebugNetworkShaper` holds every media download's response in `MultiplexedRequestManager` until one link per process
  with that round trip and bandwidth would have delivered it; a held response keeps its worker slot. Main-session API
  calls are not shaped. The playback lab in `Tests/` uses the same profiles, so lab and simulator numbers compare.
- Goldens (`Tests/HLSJSGoldens.swift`) are hls.js's own output: regenerate with
  `sh submodules/HLSPlayback/Tools/hlsjs-goldens/generate.sh`, never by hand. Host tests:
  `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/HLSPlayback:HLSPlaybackTests`.
