# TelegramCore/Sources/Network — agent notes

The Rust MTProto engine (engine selection, `RustEngineActions`, and the gates a logout must pass) is
`submodules/MTProtoRustEngine/CLAUDE.md`: read it before touching the engine, permanent-key or logout paths here.

## Network telemetry (`NetworkTelemetry`)

TelegramCore records every request of an account's network above the engine (`RecordingNetworkEngine.swift`), so
MtProtoKit and the Rust engine are measured by the same code: per-method counts, retries, failures and latency buckets
for a server-driven A/B, and a `NetworkFailureRecord` for every failed, abandoned, dropped, slow or stalled request with
the context to reproduce it (connection timeline, latency p50/p90, estimated requests in flight, retries). Records
persist in `<account>/network-telemetry/` and are reported through `help.saveAppLog` (`network_telemetry_summary` /
`network_telemetry_failures`) while the app config sets `network_telemetry_enabled`; `network_telemetry_variant`
labels the arm. A period ends when it is reported and when the variant, app or system version, or layer changes, so a
report can carry several summaries, each with its own labels. Debug builds always record and never report on their
own. `mtproto-bench replay` (engine repo README) turns records back into bench runs against the test server.

None of this shows up as a build error:

- **Recording off must cost nothing.** The wrapper is installed only when recording, so with it off the request path
  carries no telemetry code. A/B every request-path change three ways (baseline, off, on) with
  `mtproto-bench tc --suite torture --only million-clean`. Recording on costs ~0.4 µs per request (~13% at the 250k
  req/s ceiling).
- **Keep per-request work off the engines' serial queues.** A success appends one sample under an `os_unfair_lock`;
  counting happens in batches on a utility queue. Aggregating inline, a shared list written by the issuing thread, or
  any extra per-request object that outlives `add` and crosses threads cost 33%, 13% and ~10%. So the state
  lives inline in `NetworkEngineRequest`, the engine's own disposable is returned unchanged, abandonment is noticed in
  the request's `deinit` (engines must release a request once it is cancelled), and only one request in eight is
  watched for stalls.
- **Only active waiting counts.** The main session's pauses mark the app suspended. Time spent suspended and server
  flood waits never count toward slow, stalled or abandoned; a stall is counted only from when the connection last
  came up; requests that waited through a suspension or a flood wait stay out of the latency histogram. The clock is
  `CLOCK_UPTIME_RAW`, so device sleep does not count either. `dropped` (an engine returning `EmptyDisposable`) exists
  only where an engine refuses requests (Rust and the switching wrapper), so leave it out of engine comparisons.
- **Anonymization is enforced by tests.** `testReportedFieldsAreAllowlisted` pins every key that leaves the device.
  Method names come from `FunctionDescription.name` only, never from `shortMetadata.description`: `upload.getWebFile`
  passes its full description, URL included, as short metadata, and a request's metadata keeps every argument (upload
  parts too), so nothing kept for counting may hold it. Error texts must be upper-case server constants (anything else
  becomes `OTHER`) and lose numbers and tokens; request sizes are rounded up to a power of two.

## Media downloads (`FetchV2`)

- **A file's parts come from its highest priority first** (`fetchV2PriorityRanges`, `fetchV2TakeNextPart`,
  `FetchV2PrioritySelectionTests`). A range asked for at two priorities is only in the higher bucket, and a taken part
  leaves every bucket, so no byte is fetched twice. A lower bucket of a file waits until the higher ones are empty: the
  chat preload of a quality file (`.default`) waits behind the player streaming it (`.elevated`), for as long as the
  player's buffer takes to fill. Parts in flight are never preempted. Across files the order is
  `MultiplexedRequestManager`'s: `pushPriorityDownload`, then FIFO.
- **`DownloadThroughputMeter`** (one per `Network`) takes every media part's bytes and engine send-to-receive time
  (`requestWithAdditionalInfo`; a part without a duration is not recorded) and reports bits over the union of the
  parts' intervals in the last 120 s, nil below 512 KB. It feeds no telemetry; `TelegramEngine.resources` exposes it
  for the HLS player's first estimate. In debug builds with `-debugNetworkProfile`, `DebugNetworkShaper` reports a held
  response's network time as the shaped link's, so the meter measures the simulated network.
- **A refreshed file reference is not kept across fetches:** each fetch of a file starts from its caller's reference.
  The refresh log line says "again in this process" when one resource is refreshed twice, the evidence for whether a
  cache is worth building.
