# Native HLS player (`HLSPlayback`)

HLS videos play through `submodules/HLSPlayback`, a Foundation-only Swift port of the parts of hls.js 1.7.3 our streams
use: the playlist parser, the EWMA estimator, ABR with abandon, a buffer model and an event-driven
`HLSPlaybackController`. The app's environment (`TelegramUniversalVideoContent/Sources/HLSNative/`) feeds
`ChunkMediaPlayerV2` through its `.custom` source, and `HLSVideoNativeContentNode` is the content node. The deviations
from hls.js (D1–D13), the failure policy, the logs and the measurements are in
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
