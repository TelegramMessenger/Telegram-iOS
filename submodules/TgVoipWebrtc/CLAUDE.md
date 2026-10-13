# tgcalls Library

The tgcalls VoIP library source. See the root `CLAUDE.md` for build instructions and the project overview.

## macOS Build Support

This repo has been patched to support native macOS arm64 builds (`darwin_arm64` CPU) in addition to the original iOS targets. Changes made:
- `third-party/webrtc/BUILD` — added `@platforms//os:linux` to `arch_specific_cflags` select (fixes macOS getting Linux flags via `//conditions:default`); moved `cocoa_threading.mm` from `cc_library` to `webrtc_platform_helpers` `objc_library` (Bazel 8 rejects `.mm` in `cc_library`); replaced UIKit with AppKit for macOS
- `third-party/openh264/BUILD` — added `//conditions:default` to `select()` statements
- `third-party/webrtc/absl/absl/base/attributes.h` — disabled `ABSL_ATTRIBUTE_LIFETIME_BOUND` (newer Xcode clang rejects it on void-returning functions)

### Vendored webrtc seams for tgcalls (no behaviour patches)

The fork carries five additive seams, each marked
`TGCALLS SEAM (<consumer>)` in the source. None changes behaviour for a caller
that does not opt in. When bumping webrtc, carry these forward, and drop one
the moment upstream grows an equivalent.

| Seam | Where | Consumer |
|---|---|---|
| `PeerConnectionDependencies::dtls_transport_factory` | `api/peer_connection_interface.h`, `pc/peer_connection.{h,cc}` (plumbed to the `JsepTransportController::Config` field that already existed) | `tgcalls::MtProtoDtlsTransportFactory` |
| `PeerConnectionFactoryInterface::Options::external_transport_security` | `api/peer_connection_interface.h`; `pc/peer_connection.cc` in `InitializeTransportController_n` (`config.disable_encryption`) and `SrtpRequired()` | `InstanceV2ReferenceImpl`, `CallCoreHost` under `network_use_mtproto` |
| `PeerConnectionObserver::OnUnDemuxableRtpPacket(const RtpPacketReceived&)` | `api/peer_connection_interface.h`; `pc/peer_connection.cc` in `InitializeUnDemuxablePacketHandler` (network thread, before the hand-off to `Call`) | `GroupInstanceReferenceImpl` late-speaker SSRC discovery |
| `RTCConfiguration::disable_payload_type_demuxing` | `api/peer_connection_interface.h`; `pc/peer_connection.cc` (equality struct); read in `SdpOfferAnswerHandler::UpdatePayloadTypeDemuxingState` in `pc/sdp_offer_answer.cc` | `GroupInstanceReferenceImpl` (2026-09-19): with the MID extension stripped from the answer, stock WebRTC routes unknown SSRCs by payload type to whichever audio m-line is the only receiving one, creating unsignaled receive streams there; this engine signals every SSRC and discovers new ones from the dropped packets, so it opts out |
| `PeerConnectionSdpMethods::ResetSctpDataMidAfterRollback()` | `pc/peer_connection_internal.h`, `pc/peer_connection.{h,cc}`; called from `SdpOfferAnswerHandler::Rollback` in `pc/sdp_offer_answer.cc` | every PeerConnection engine, no opt-in — the one seam that changes stock behaviour, and only in a state stock never recovers from (below) |

The rollback seam (2026-09-17) closes a wedge that stock WebRTC cannot leave:
when the description that first set up the data-channel transport is rolled
back by a colliding remote offer, `sctp_mid` keeps naming an m-section no
stable description has (and which the remote offer may reuse for media).
`CheckIfNegotiationIsNeeded` then returns true forever for the missing data
section while `GetOptionsForUnifiedPlanOffer` never adds one because the mid is
set — an offer/answer loop for the rest of the call, one round per signaling
RTT, stopping the video send stream twice and flapping the audio channel each
round. The seam releases the mid (signaling- and network-side, without closing
the channels, so `HasDataChannels()` stays true) and the next offer renegotiates
data under a fresh mid. Production hit it in every 18/19 video call
(`getlogstgcalls/analysis/FINDINGS-v19-video-loop.md`); the engine-side cause
is fixed too (see `tgcalls/v2wasm/CLAUDE.md`), this seam is the backstop for any
future start glare. Reproduce/verify with the CLI: `tgcalls_cli --mode p2p
--version 19.0.0 --version2 19.0.0 --video` must show 4 description sets per
call and one `Creating data channel`.

History, so nobody reintroduces them: between 2026-09-01 and 2026-09-16 the
fork carried three *behaviour* patches instead ("Allow SCTP without DTLS" in
`pc/peer_connection.cc` and `pc/media_session.cc`, "Inactive DtlsTransport
forwards packet flags" in `p2p/base/dtls_transport.cc`), all consequences of
using `Options::disable_encryption` for mtproto. Engine-side detail and the
regression they caused are in `tgcalls/CLAUDE.md` under "mtproto transport on
the PeerConnection engines"; the design record is
`docs/superpowers/specs/2026-09-16-tgcalls-mtproto-dtls-slot-design.md`.

- 8 third-party BUILD files + 8 build shell scripts — added `darwin_arm64 -> macos_arm64` architecture support (opus, libvpx, ffmpeg, dav1d, mozjpeg, webp, libjxl, td)

## Linux Build Support

The repo supports native Linux arm64 and x86_64 builds. Key changes from the iOS/macOS-only baseline:
- `.bazelrc` — Apple toolchain settings under `build:macos`, Linux uses default CC toolchain via `build:linux` (auto-selected by `--enable_platform_specific_config`)
- `build-system/BUILD` — `linux_arm64` and `linux_x86_64` config_settings
- `objc_library` → `cc_library` conversions for pure C/C++ targets (ogg, opusfile, rnnoise, opus, libvpx, dav1d, ffmpeg wrappers, WebRTC main target)
- WebRTC BUILD — platform flags via `select()` (`-DWEBRTC_LINUX` vs `-DWEBRTC_MAC`), stdlib task queue instead of GCD on Linux, macOS-only sources excluded
- Third-party genrule build scripts — Linux architecture cases added (libvpx, dav1d, ffmpeg), system cmake/meson/ninja used instead of downloaded macOS binaries
- BoringSSL — `_Generic` C11 guarded for C++ mode (GCC compatibility)
- tgcalls headers — `#include <cstdint>` added for GCC 15 strictness

## SCTP Signaling

### Writable Gate (role-based handshake ordering)

tgcalls uses a custom SCTP association (via dc-sctp) over the signaling channel for reliable message delivery. `SignalingSctpConnection` wraps `DcSctpTransport` with a `SignalingPacketTransport` shim.

The SCTP handshake is ordered using DcSctpTransport's writable gate (`MaybeConnectSocket()`), mirroring how WebRTC PeerConnection uses DTLS writable state to control SCTP connection timing:

- **Caller** (`isOutgoing=true`): `SignalingPacketTransport` starts writable → `Connect()` fires immediately → sends INIT
- **Callee** (`isOutgoing=false`): starts not-writable → `Connect()` deferred → on first `receiveExternal()`, `setWritable(true)` fires `SignalWritableState` → `MaybeConnectSocket()` → `Connect()`

The callee's `Connect()` and processing of the caller's INIT happen synchronously within the same `BlockingCall` on the network thread (RFC 4960 §5.2.1 simultaneous-open).

Key files:
- `SignalingSctpConnection.cpp` — `SignalingPacketTransport` writable state, `setWritable()`, constructor takes `isInitiator`
- `InstanceV2Impl.cpp` / `InstanceV2ReferenceImpl.cpp` — pass `_encryptionKey.isOutgoing` as `isInitiator`
- `third-party/webrtc/webrtc/media/sctp/dcsctp_transport.cc:662-667` — `MaybeConnectSocket()` gate (unmodified)

### Timer Tuning (CustomDcSctpSocket)

WebRTC's stock `DcSctpSocket` has a bug: `max_timer_backoff_duration` is wired to the T3-rtx (data retransmission) timer but **not** to the t1_init and t1_cookie (handshake) timers. The handshake timers use unlimited exponential backoff (1000, 2000, 4000, 8000ms...), causing the SCTP handshake to stall for 20+ seconds under packet loss with simultaneous-open (both sides call `Connect()`).

Fix: `CustomDcSctpSocket` (in `tgcalls/v2/`) is a copy of `DcSctpSocket` with the 6-line fix that passes `max_timer_backoff_duration` to the t1_init and t1_cookie timer constructors. A `CustomDcSctpSocketFactory` in `SignalingSctpConnection.cpp` creates it instead of the stock socket, with configurable timer overrides. WebRTC source is **untouched**.

Default signaling SCTP timer values (set in `SignalingSctpConnection::Options`):

| Setting | WebRTC Default | Signaling Override |
|---|---|---|
| `t1_init_timeout` | 1000ms | 400ms |
| `t1_cookie_timeout` | 1000ms | 400ms |
| `max_timer_backoff_duration` | 3000ms | 750ms |
| `max_init_retransmits` | 8 | unlimited (from `DcSctpTransport::Start`) |

Retry pattern: 400ms, 750ms, 750ms, 750ms... (~18 attempts in 15s). At 30% loss, 100% success rate over 5000 runs.

These values are configurable via JSON custom parameters (passed to `InstanceV2Impl` via `config.customParameters`):
- `network_sctp_t1_init_ms` — T1-init timeout (0 = use default 400ms)
- `network_sctp_t1_cookie_ms` — T1-cookie timeout (0 = use default 400ms)
- `network_sctp_max_backoff_ms` — max timer backoff cap (0 = use default 750ms)

Key files:
- `tgcalls/v2/CustomDcSctpSocket.h/.cpp` — patched `DcSctpSocket` copy
- `tgcalls/v2/SignalingSctpConnection.cpp` — `CustomDcSctpSocketFactory`, timer option plumbing
- `tgcalls/v2/InstanceV2Impl.cpp` — reads JSON params, passes `Options` to `SignalingSctpConnection`

## InstanceV2CompatImpl (version 14.0.0)

A cross-version interop implementation that uses WebRTC PeerConnection internally (like InstanceV2ReferenceImpl) but speaks V2Impl's signaling protocol (`InitialSetupMessage`, `NegotiateChannelsMessage`, `CandidatesMessage`). This enables bidirectional calls between PeerConnection-based clients and V2Impl-based clients (versions 7.0.0–13.0.0).

### Architecture

```
PeerConnection <-> SignalingTranslator <-> EncryptedConnection <-> SignalingSctpConnection
```

- **SignalingTranslator** (`tgcalls/v2/SignalingTranslator.h/.cpp`): Converts between `cricket::SessionDescription` (PeerConnection's internal format) and V2Impl signaling messages. Uses `JsepSessionDescription` programmatic API — no SDP string round-trips.
- **Outbound**: PeerConnection generates offer/answer → SignalingTranslator extracts `InitialSetupMessage` (transport params) + `NegotiateChannelsMessage` (media contents)
- **Inbound**: Buffers both messages until complete → builds `cricket::SessionDescription` → wraps in `JsepSessionDescription` → `SetRemoteDescription`

### Key Design Decisions

- **No data channel with V2Impl peers**: WebRTC data channel requires PeerConnection on both sides. V2Impl uses NativeNetworkingImpl (no PeerConnection). When paired with V2Impl, the data channel m-line is padded as `rejected` in the remote answer so PeerConnection accepts it. For CompatImpl↔CompatImpl calls, the data channel works normally.
- **Caller-only renegotiation**: Only the outgoing side triggers offers from `onRenegotiationNeeded` to prevent unsolicited offer storms.
- **MediaState via signaling**: `MediaStateMessage` sent over the SCTP signaling channel (not data channel), ensuring it works with both V2Impl and CompatImpl peers.
- **Sequential content IDs**: Uses "0", "1", ... as m-line mids, matching PeerConnection's default scheme.
- **Shared conversion functions**: `convertContentInfoToSignalingContent()` and `convertSignalingContentToContentInfo()` extracted to `Signaling.h/.cpp` for use by both `ContentNegotiationContext` (V2Impl) and `SignalingTranslator` (CompatImpl).

### Cross-Version Testing

```bash
# CompatImpl caller → V2Impl callee
./bazel-bin/tools/tgcalls_cli/tgcalls_cli --mode p2p --version 14.0.0 --version2 13.0.0 --duration 10 --quiet

# V2Impl caller → CompatImpl callee
./bazel-bin/tools/tgcalls_cli/tgcalls_cli --mode p2p --version 13.0.0 --version2 14.0.0 --duration 10 --quiet

# With lossy signaling
./bazel-bin/tools/tgcalls_cli/tgcalls_cli --mode p2p --version 14.0.0 --version2 13.0.0 --duration 15 --drop-rate 0.3 --delay 50-200 --quiet
```

100% success rate at 30% loss in both directions (tested with 50 sequential + 20 parallel runs each direction).

Key files:
- `tgcalls/v2/InstanceV2CompatImpl.h/.cpp` — main implementation
- `tgcalls/v2/SignalingTranslator.h/.cpp` — cricket↔signaling conversion
- `tgcalls/v2/Signaling.h/.cpp` — shared conversion functions (`convertContentInfoToSignalingContent`, `convertSignalingContentToContentInfo`)

## GroupInstanceCustomImpl (Group Calls)

The group call implementation in `tgcalls/group/GroupInstanceCustomImpl.cpp` (~4700 lines). Uses a client-server model with an SFU, unlike 1:1 calls which are peer-to-peer.

### Protocol Stack
- **Join signaling**: JSON over application layer (`emitJoinPayload` → app sends to SFU → `setJoinResponsePayload`)
- **Transport**: ICE + DTLS-SRTP over UDP (standard WebRTC transport, NOT PeerConnection)
- **Media**: RTP/RTCP with Opus audio (48kHz, 2ch, 32kbps), optional VP8/H264/VP9 video
- **Control**: SCTP data channel over DTLS for Colibri protocol (video constraints, debug messages)

### Join Flow
1. Client calls `emitJoinPayload()` → generates JSON with audio SSRC, ICE ufrag/pwd, DTLS fingerprint
2. Application sends JSON to SFU server
3. Server responds with its ICE candidates, DTLS fingerprint, video codec info
4. Client calls `setJoinResponsePayload(json)` → ICE/DTLS negotiation begins
5. On connection: `networkStateUpdated` callback fires

### Participant Discovery
- Unknown SSRC arrives in RTP → `receiveUnknownSsrcPacket()` → `maybeRequestUnknownSsrc(ssrc)`
- App's `requestMediaChannelDescriptions` callback queries server for SSRC→participant mapping
- `addIncomingAudioChannel(ssrc, userId)` creates decoder channel

### Colibri Data Channel Messages
```json
// SFU → Client
{"colibriClass": "SenderVideoConstraints", "videoConstraints": {"idealHeight": 360}}

// Client → SFU
{"colibriClass": "ReceiverVideoConstraints", "defaultConstraints": {"maxHeight": 0},
 "onStageEndpoints": ["endpoint1"],
 "constraints": {"endpoint1": {"minHeight": 180, "maxHeight": 720}}}
```

Heights are on the layer scale 180/360/720 (thumbnail/medium/full): `minHeight` from the channel's
`minQuality`, `maxHeight` from its `maxQuality`, and every `maxQuality == Full` endpoint is listed in
`onStageEndpoints` (`maybeUpdateRemoteVideoConstraints`). Both engines must send exactly this shape;
see "Receiver video constraints" under ReferenceImpl for what happened when one did not.

### Key Files
- `tgcalls/group/GroupInstanceCustomImpl.h/.cpp` — main implementation
- `tgcalls/group/GroupNetworkManager.h/.cpp` — ICE/DTLS/SRTP transport
- `tgcalls/group/GroupJoinPayloadInternal.h/.cpp` — join JSON serialization

## GroupInstanceReferenceImpl (PeerConnection-based Group Calls)

An alternative group call implementation that uses standard WebRTC PeerConnection instead of the manual ICE/DTLS/SRTP management in `GroupInstanceCustomImpl`. Supports both audio and video (H264 simulcast). Implements the same `GroupInstanceInterface`.

**Selection in the app:** opt-in in any build through Debug Settings ▸ "Group calls: reference engine" (`ExperimentalUISettings.groupCallReferenceEngine`, read in `PresentationGroupCall.swift` when the call context is created — a running call keeps its engine), or from the server via the `ios_calls_group_reference_impl` app-config flag (non-zero turns it on; it cannot turn the debug switch off). Live streams always use the custom engine: the reference engine has no broadcast mode. Before 2026-09-04 the reference engine was the default of every DEBUG build, which is what the fixed real-call bugs above were found under.

**Reference-engine calls wrote EMPTY log files until 2026-09-08.** The constructor built its
`LogSinkImpl` and the destructor called `RemoveLogToStream` on it, but nothing ever called
`AddLogToStream` — so every `log-<date>.log` produced by a call on this engine was zero bytes,
and no reference-engine call could be diagnosed from a log at all. If you are looking at a bug
report with empty call logs interleaved with populated ones, the empty ones are this engine.

### Architecture

```
GroupInstanceReferenceImpl
  └── PeerConnection (single, to SFU)
        ├── sendrecv audio transceiver (outgoing audio)
        ├── sendonly video transceiver (outgoing H264 simulcast, SDP-munged SSRCs)
        ├── recvonly audio transceivers (one per remote SSRC, added dynamically)
        ├── recvonly video transceivers (one per remote endpoint, added dynamically)
        └── data channel ("data", for ActiveVideoSsrcs and Colibri video constraints)
```

### How It Differs from CustomImpl

| Aspect | CustomImpl | ReferenceImpl |
|--------|-----------|---------------|
| Transport | Manual ICE/DTLS/SRTP via GroupNetworkManager | WebRTC PeerConnection |
| SDP | None (custom JSON protocol) | Local SDP construction, translates to/from JSON |
| SSRC discovery | `unknownSsrcPacketReceived` on raw RTP | Audio: the packets `RtpDemuxer` drops, via the `OnUnDemuxableRtpPacket` seam — the only path; mid=0 is sendonly and payload-type demuxing is off (see below). Video: `ActiveVideoSsrcs` data channel message from SFU |
| Audio channels | Manual `IncomingAudioChannel` per SSRC | PeerConnection recvonly transceivers |
| Audio levels | RTP header extension parsing | Per-receiver `GRAudioLevelSink` reading real PCM levels |
| Video outgoing | Manual `cricket::VideoChannel` with direct SSRC control | PeerConnection sendonly transceiver + SDP munging for simulcast SSRCs |
| Video incoming | Manual `IncomingVideoChannel` per endpoint | PeerConnection recvonly transceivers with SSRCs in answer |
| Video decode | Manual decoder lifecycle | PeerConnection handles internally |
| Code size | ~4700 lines | ~1500 lines |

### Join Flow (SDP Translation)

1. Create PeerConnection with a **sendonly** Opus audio transceiver (mid=0 never receives), sendonly video transceiver (no track), and data channel; `RTCConfiguration::disable_payload_type_demuxing = true`
2. `createOffer` → munge video SSRCs (replace PeerConnection's auto-generated SSRCs with pre-allocated simulcast SSRCs) → `SetLocalDescription` → extract ICE/DTLS params from local SDP
3. Serialize as JSON (same format as CustomImpl): `{ssrc, ufrag, pwd, fingerprints, ssrc-groups}`
4. Parse SFU response JSON → construct `JsepSessionDescription("answer")` programmatically via `cricket::SessionDescription` API (no SDP string parsing)
5. `SetRemoteDescription` → ICE/DTLS connects via PeerConnection internals
6. Add remote ICE candidates via `AddIceCandidate` after `SetRemoteDescription`
7. Activate outgoing video: attach `FakeVideoTrackSource` track to the existing sendonly transceiver via `sender()->SetTrack()` — no renegotiation needed

### Dynamic Participant Handling

**Audio (one recvonly m-line per SSRC, discovered from dropped packets):**
1. The first packet for an unknown SSRC X matches no m-line: mid=0 is sendonly, every recvonly audio m-line signals its own SSRC, the answer carries no MID extension and payload-type demuxing is disabled for the PeerConnection (`RTCConfiguration::disable_payload_type_demuxing`, a seam). `RtpDemuxer` drops it and `RtpTransport` reports the drop through `PeerConnectionObserver::OnUnDemuxableRtpPacket` (another seam), parsed and SRTP-unprotected, on the network thread.
2. `GRPeerConnectionObserver::onUnDemuxableRtpPacket` matches payload type 111 (Opus is pinned in group calls, so audio is identifiable without parsing the payload), reads `packet.Ssrc()`, de-dupes under `AudioSsrcTap`, and posts `handleDiscoveredAudioSsrc(X)` to the media thread. Nothing is buffered; CustomImpl does not buffer either (`MissingSsrcPacketBuffer` is vestigial), so X is inaudible until step 4, as it is there.
3. `handleDiscoveredAudioSsrc(X)` inserts X into `_remoteSsrcs` with a fresh mid, fires `_requestMediaChannelDescriptions({X}, ...)` (matches CustomImpl's contract), and calls `scheduleDiscoveryRenegotiation()` (250 ms debounce).
4. After the debounce, `renegotiate()` adds a recvonly audio transceiver bound to mid=`_nextMid++` for every entry in `_remoteSsrcs` that doesn't have one. `buildRemoteAnswer` includes X on the new m-line; each recvonly transceiver gets its **own** `SetDepacketizerToDecoderFrameTransformer` instance (pass-through, or the e2e decryptor), installed right after `AddTransceiver` and before the SDP cycle assigns the signaled SSRC.
5. `onRenegotiationComplete` runs `wireRemoteAudioLevelSinks()`, attaching a `GRAudioLevelSink` per receiver; that sink is the only source of the participant's level, so a receiver that never gets packets is a participant who is never shown speaking.

Measured with the CLI (3 reference participants): first level data ~280 ms after the first dropped packet (the debounce plus one offer/answer), versus immediate playback when mid=0 still received. CustomImpl pays the same delay.

The `colibriClass=ActiveAudioSsrcs` data-channel mechanism (test-SFU only) was removed. Removed-SSRC handling is the same as CustomImpl: stale recvonly transceivers stay in the SDP indefinitely; participant departures are tracked at the application layer (MTProto).

**Why mid=0 must not receive (history).** Until 2026-09-19 mid=0 was sendrecv and acted as WebRTC's
catch-all: unknown SSRCs were routed to it by payload type, the voice channel created an unsignaled
`WebRtcAudioReceiveStream` per SSRC, and a `GRAudioFrameTransformer` registered as mid=0's
`unsignaled_frame_transformer_` reported each SSRC on first sight while the frame played through.
That design failed twice:

1. *It died at the first renegotiation* (fixed 2026-09-08 with the un-demuxable tap).
   `SdpOfferAnswerHandler::UpdatePayloadTypeDemuxingState` disables payload-type demuxing for a
   BUNDLE group as soon as two receiving m-lines of one kind advertise the same payload type, and
   every audio m-line here advertises Opus 111, so the first discovery renegotiation tripped it
   permanently; a participant who started sending afterwards was dropped by `RtpDemuxer` before any
   stream existed and was inaudible for the rest of the call.
2. *The reset raced the packets in flight* (found 2026-09-19 in the CLI, fixed by this design). The
   same renegotiation calls `ResetUnsignaledRecvStream()` on mid=0 — but a packet the network thread
   had already handed to the worker recreated an unsignaled stream right after the reset, mid=0 was
   never reset again, and that stream kept the SSRC's binding in the Call's `RtpDemuxer`. The
   dedicated m-line added for the SSRC then logged `Sink could not be added for SSRC=...`: the
   participant stayed audible through the stray stream but their `GRAudioLevelSink`, on the dead
   receiver, never fired, so peers never saw them as speaking. In a 3-participant run 2 of 6 level
   sinks were dead. With mid=0 sendonly there is no channel for WebRTC to create such a stream on,
   and with payload-type demuxing off the lone recvonly m-line cannot become the catch-all either
   (it did, for a late unmuter, in the first attempt at this change — `unmute-after` scored 0/2).

An app-side roster (`addSsrcs` from the participant list) was implemented first and rejected: this
engine adds one recvonly m-line per SSRC and a voice chat's roster runs to thousands.

CLI regression: `--mute-participants N --unmute-after S`, with **nothing signalled to the peers** at
the unmute — they must notice the SSRC from the media alone. Before the fix a mixed group scored
`Late unmute heard: 1/2` and the reference receiver never logged `queued discovered audio SSRC` for
the late SSRC at all; the same late unmute with no prior renegotiation passed, which is what proved
the trigger was the renegotiation rather than the lateness.

**Mute must stop the stream, not silence it (2026-09-15).** `setIsMuted` used to call only
`_outgoingAudioTrack->set_enabled(false)`. In WebRTC that reaches `ChannelSend::SetInputMute`, which
zeroes the samples but keeps encoding and sending, so a muted reference participant still emitted a
full Opus stream (~50 packets/s at level 0) — invisible to every level-based check and to the peers,
but paid for by the SFU and every receiver. What actually starts and stops the `AudioSendStream` is
the sender's `encodings[0].active` (`WebRtcAudioSendStream::UpdateSendState`; note this vendored
WebRTC starts the stream even with no source, so `SetTrack(nullptr)` would NOT stop it).
`applyOutgoingAudioMuteState()` toggles it through `GetParameters`/`SetParameters` with no
renegotiation — the PeerConnection counterpart of CustomImpl's `Enable(!_isMuted)` — keeps the
track disabled, and applies the ADM microphone mute as CustomImpl's `onUpdatedIsMuted` does (on iOS
that is the system mute, which is also what drives the muted-speech hint; the reference engine never
engaged it before). It also runs from `start()` so the stream is stopped from the first negotiation,
via the sender's init parameters. Stopping the only send stream makes `AudioState` stop ADM
recording, exactly as CustomImpl's muted state does; the muted-speech detector lives in the audio
unit, not in the recording path, so it is unaffected. CLI regression: `--mute-participants` now
fails on `Muted audio leaks` (audio RTP counted at the SFU per SSRC) — 456 packets before, 0 after.

**Outgoing Opus frame duration is decided in `buildRemoteAnswer` (2026-09-15).** WebRTC derives the
send codec from the *remote* answer (`VoiceChannel::SetRemoteContent_w`), and this engine fabricates
that answer itself, so the Opus `ptime` written there is the frame duration we send. Without it the
encoder used WebRTC's 20 ms default: ~50 packets/s, three times the iOS CustomImpl (which requests
120 but is clamped to 60 because this build no longer defines `WEBRTC_OPUS_SUPPORT_120MS_PTIME` —
active from 2021-06 until the 2024-03-15 Opus 1.5.1 upgrade commented it out, for no stated reason
and in exchange for `WEBRTC_OPUS_SUPPORT_DRED`/`WEBRTC_OPUS_USE_CODEC_PLC`, which no source consumes
and whose libopus is built without `--enable-dred`) and six times Android and desktop, whose builds
keep the define and really send 120 ms frames. The answer now carries `ptime=60; maxptime=120`,
standard RFC 7587 SDP that a server-produced answer can take over verbatim. 60 rather than 120: it
is what iOS custom participants have shipped since 2024, needs no build flag, and keeps small
conference calls responsive; the extra step to 120 saves only ~4 kbit/s more of per-packet overhead
for another 60 ms of delay and a 120 ms hole per lost packet. The CLI's per-SSRC counts show it:
a reference participant fell from 476 to 170 packets in a 10 s run, against 142 for a custom one,
and the encoder log line reads `ptime: 60`. Note WebRTC's Audio Network Adaptor is not a substitute
here: it adapts frame length to the sender's uplink estimate, which cannot see the SFU fan-out.

The **discovery tap** is installed once on mid=0's receiver only. Each recvonly receiver gets its own separate transformer instance — sharing ONE instance across receivers triggers `Register{Sink,}TransformedFrameCallback` re-runs that overwrite valid registrations and misroute frames.

**Video:**
1. SFU sends `ActiveVideoSsrcs` over data channel → forwarded to app via `dataChannelMessageReceived` (test SFU only; the real app learns endpoints + SSRC groups from the MTProto participant list, usually BEFORE joining)
2. App calls `setRequestedVideoChannels()` → the full set is stored in `_requestedVideoChannels`; if the join response has not been applied yet (`!_isJoined`) it is only recorded and `onJoined()` applies it later. Otherwise `applyRequestedVideoChannels()` adds recvonly video transceivers (and re-flags any existing endpoint whose transceiver still has no mid, so a failed cycle is retried) and sends `ReceiverVideoConstraints` over the data channel
3. Renegotiate: new offer → munge outgoing video SSRCs → `SetLocalDescription` → build answer with incoming video SSRCs → `SetRemoteDescription`
4. `wirePendingVideoSinks()`: attach `FakeVideoSink` to the recvonly transceiver's receiver track after `SetRemoteDescription` completes
5. Renegotiations are serialized (`_isRenegotiating` / `_pendingRenegotiation` flags) to prevent overlapping offer/answer cycles, and `renegotiate()` refuses to run before `_isJoined`
6. `onDataChannelStateChanged()` re-sends `ReceiverVideoConstraints` for `_requestedVideoChannels` when the channel opens — `sendReceiverVideoConstraints` silently drops the message while the channel is still connecting, and the SFU forwards no video until it has received constraints

**Why the join gate exists (2026-09-04, from a real-call log):** the app calls `setRequestedVideoChannels` right after the context issues `emitJoinPayload`, so the request lands on the media thread behind the initial `CreateOffer` and before its `SetLocalDescription`. Renegotiating there is unrecoverable: a transceiver with no mid gets a FRESH mid from PeerConnection's monotonic `UniqueNumberGenerator` on every `CreateOffer` (`pc/sdp_offer_answer.cc` `GetOptionsForUnifiedPlanOffer`), so the initial offer took mids 0/1/2 and the renegotiation offer got 3/4/5/6; `SetLocalDescription` rejected it with "The order of m-lines in subsequent offer doesn't match order from previous offer/answer", nothing retried (later identical requests hit the "endpoint already known" early-continue), the constraints had been dropped on the closed data channel, and incoming video never arrived. Even with a matching offer, `buildRemoteAnswer()` before the join response runs on an empty `_remoteTransport`. The CLI reproduces it with `--early-video-request` (fails 1/2 video pairs on the old code, 2/2 after the fix).

### A failed audio-unit start used to be permanent for the call (fixed 2026-09-05)

Before the fix, `AudioDeviceIOS::StartPlayout` returned -1 *before* `playing_.store(1)` when
`audio_unit_->Start()` failed, and nothing above it retried: the app's shared device
(`WrappedAudioDeviceModuleIOS::Start()` in `Sources/OngoingCallThreadLocalContext.mm`) latched
`_isStarted` before knowing the outcome and ignored the StartPlayout/StartRecording results,
`AudioDeviceModuleIOS::StartPlayout` reported `Playing() == true` after the failure so every later
attempt skipped the device, and `UpdateAudioUnit` (route changes, interruption recovery) only
restarts a unit whose `playing_`/`recording_` is already set. One failed start silently disabled
playout for the rest of the call while capture kept working.

Observed 2026-09-04 on the simulator, on a fast leave→rejoin. The second join's `StartPlayout`
raced the `AVAudioSession` activation against a HAL still disposing the previous device
(`AudioObjectGetPropertyData: no object with given ID`, `AQMEIO … (maybe stale)`) and got
`AUIOClient_StartIO failed (-66637)`; `StartRecording` then started the *same*
Voice-Processing I/O unit successfully 7 ms later. Result: mic worked, video worked, incoming
audio was silent for the whole call. The symptom reads exactly like a decryption failure in an
encrypted conference — the frame transformers drop silently — so check the device start before
suspecting crypto.

What changed (2026-09-05, runtime unverified at the time of writing):

- `AudioDeviceModuleIOS::StartPlayout`/`StartRecording` unwind the audio device buffer on
  failure and leave `Playing()` false; `StopPlayout` resets it; `Terminate` unwinds the module
  state and, in `AudioDeviceIOS::Terminate`, releases a unit that was initialized but never
  started (`ShutdownPlayOrRecord`). `Init()` after `Terminate()` creates a fresh device and
  re-applies the last tone (`lastTone_`), so a retry starts clean.
- The shared device's `Start()` checks every step, rolls back with `Terminate()` on failure,
  returns a bool, and `SharedAudioDeviceModuleImpl` retries on the worker thread
  (`PostDelayedTask`, 6 attempts 500 ms apart, re-armed by the next activation). The outcome
  reaches the app log as `CallAudioDevice: audio device started …` /
  `… start attempt N failed: <step> failed with <code>`. The old `sleep(1)` retry loop is gone.
- `SharedCallAudioDevice` forwards only activation *transitions* to `RTCAudioSession`, and a
  `stop` retires a device for good. `SharedCallAudioContext` retires the previous call's context
  when the next one is created (if that call had terminated), so a redial no longer restarts the
  old Voice-Processing unit next to the new one — the overlap that produced the -66637 above.
- The vendored `RTCAudioSession` can no longer deactivate the real `AVAudioSession`.
  `updateAudioSessionAfterEvent` (reached from interruption-ended, media-services-lost/reset
  and app-became-active-while-interrupted) was the last real `setActive:` call in the file
  (`-setActive:error:` is `shouldSetActive && false`), and with the pre-fix negative activation
  count it resolved to `setActive:NO` on the CallKit session mid-call. It now only activates
  (count > 0) or updates the `isActive` flag (count == 0); activation and deactivation are owned
  by CallKit and `ManagedAudioSession`.

All of the above is on by default and reverts as a unit under the server killswitch
`ios_killswitch_disable_call_audio_device_fixes` (presence of the key, like the other
`ios_killswitch_` keys). It is read where the other call killswitches are read
(`PresentationCallImpl.init`, `PresentationGroupCallImpl.init`) and applied process-wide through
`OngoingCallContext.AudioDevice.setLegacyBehaviorEnabled` → `+[SharedCallAudioDevice
setLegacyBehaviorEnabled:]` → `+[RTCAudioSession setLegacyDeactivationEnabled:]`, because one
device creator (`GroupCallContext`, used when group shared audio is itself killswitched) has no
app-config access. Under the switch a new device runs the old `StartLegacy()` verbatim (latched
`_isStarted`, `sleep(1)` retries, unchecked results), forwards every session-state value to
`RTCAudioSession` unconditionally, is never retired by the next call, and
`updateAudioSessionAfterEvent` may deactivate the session again, and `SharedCallAudioContext.get`
reuses an existing context for a group call unconditionally. Without the switch, reuse requires
the same (absent) CallKit integration on both sides: a context created for a CallKit 1:1 call
follows that call's activation through `CallKitIntegration.audioSessionActive`, so a non-CallKit
group call that reused it inherited a device nothing would re-activate once CallKit deactivated
the finished call (silent group call; invisible on the simulator, where no call has CallKit). Such
a context is now retired and the group call gets its own. The `AudioDeviceModuleIOS` /
`AudioDeviceIOS` bookkeeping fixes are not gated: on the paths the legacy flow exercises they are
behaviour-preserving (they only change failure-path state and teardown of a never-started unit).

A raw `AudioDeviceModuleIOS` driven by WebRTC's own `AudioState` (no shared device) also
benefits: `AudioState` re-issues `InitPlayout`/`StartPlayout` whenever `!adm->Playing()` on a
receive-stream change, which the honest `Playing()` now lets through.

### End-to-end encryption (conference)

`GroupInstanceDescriptor::e2eEncryptDecrypt` is honoured since 2026-09-04. Before that the
reference engine ignored it, so a conference routed here sent plaintext and could not decrypt
anything — `PresentationGroupCall` always builds an encryption context for a conference, so the
callback is always set there.

**The frame layout is shared, not reimplemented.** `group/GroupFrameTransformer.{h,cpp}` holds
the `FrameTransformer` class, the H264/VP8 plaintext-prefix helpers, `ValidateEncryptedFrame`
and four free functions (`encryptGroupAudioFrame` / `encryptGroupVideoFrame` /
`decryptGroupAudioFrame` / `decryptGroupVideoFrame`), all moved out of
`GroupInstanceCustomImpl.cpp`. A conference can mix engines, so the bytes must match
CustomImpl's exactly — including the two-byte Opus trailer and the 3→4 byte NAL start-code
widening. `//submodules/TgVoipWebrtc:group_frame_transformer_test` pins that layout.

**Four attachment points**, every one gated on `_e2eEncryptDecrypt` alone:

| Direction | Site | userId |
|---|---|---|
| Outgoing audio | `_outgoingAudioTransceiver->sender()->SetEncoderToPacketizerFrameTransformer`, `start()` | 0 |
| Outgoing video | `_outgoingVideoTransceiver->sender()->…`, `start()` | 0 |
| Incoming audio | the per-receiver transformer in `renegotiate()` | resolver |
| Incoming video | `receiver()->SetDepacketizerToDecoderFrameTransformer` in `applyRequestedVideoChannels()` | resolver |

One instance covers all outgoing simulcast layers: `WebRtcVideoSendChannel`'s `send_streams_` is
keyed by `StreamParams::first_ssrc()` only, so CustomImpl's per-SSRC install loop already
collapses to one. Installing on a sender before negotiation is safe — `RtpSenderBase` stores it
and re-applies from `SetSsrc`.

**`isConference` is NOT read by this engine, and must not be.** It is unrelated to encryption
(CustomImpl gates every transformer install on the callback too; `_isConference` there controls
only the simulcast layer count). Setting it drops outgoing video to one layer, which removes the
`SIM` ssrc-group that the SFU resolves a sender's video through — in the CLI that silently took
video from 2/2 to 0/2.

**`ssrc → userId` comes from a shared registry, not a constructor argument.** CustomImpl creates
an incoming channel *from* the `requestMediaChannelDescriptions` response, so it knows the id up
front. This engine adds its recvonly transceiver on a 250 ms debounce after SSRC discovery, which
can precede the response — and it used to discard the response entirely. `GRUserIdRegistry` is
filled from that response (audio) and from `VideoChannelDescription::userId` × its `ssrcGroups`
(video), and each decryptor resolves per frame.

**Membership decides, not the value.** An unresolved SSRC and a genuine `userId` of 0 are
indistinguishable by value (CustomImpl passes `int64_t()` for its own encryptors), so the drop
decision uses `GRUserIdRegistry::isKnown`.

**The discovery tap decrypts too.** Forwarding ciphertext to Opus renders a noise burst, and
dropping unconditionally would have been wrong under the routing claim this file used to make.
Decrypting is correct either way and keeps the discovery window audible.

**Unresolved SSRCs are re-asked.** `handleDiscoveredAudioSsrc` used to early-return on
`_remoteSsrcs.count(ssrc) > 0`, i.e. it asked exactly once ever; a response omitting the SSRC left
that participant permanently undecryptable. It now re-asks while the sender is unknown, de-duped
on the in-flight request exactly as CustomImpl's `maybeRequestUnknownSsrc` does. Transceiver
creation stays one-shot.

**The local audio level is real now.** Every outgoing Opus frame carries a level/speech trailer
before encryption, and with encryption on that trailer is the only way a CustomImpl peer learns
we are speaking (it sets `takeAudioLevelFromNetwork = false`). CustomImpl's RNNoise
`AudioCapturePostProcessor` — extracted to `group/GroupAudioCapturePostProcessor.{h,cpp}` — is
installed on this engine's APM. Two side effects reach non-conference calls: `pollAudioLevels`
now emits the **ssrc-0 self level** this engine never reported, and `setIsNoiseSuppressionEnabled`
does something (both it and its outer forwarder were no-ops).

**Testing.** `--e2e` on the CLI installs a reversible per-participant keyed transform. Note the
CLI's pass counters do **not** discriminate decrypted media from garbage: the tap used to forward
ciphertext to Opus and the level sink scored the noise, and the error-resilient H264 decoder emits
corrupt frames rather than refusing. Judge by the level *value* — a real 440 Hz sine reads a
steady ~0.126–0.133, garbage swings 0.157–1.000 — and by the wrong-key negative control, which
must drive the run to 0/2.

### Outgoing Video: SDP Munging for Simulcast

PeerConnection's API doesn't support SSRC-based simulcast directly (only RID-based, which doesn't put SSRCs in the SDP). The workaround:

1. Pre-allocate 6 random video SSRCs at construction: 3 layers × (primary + RTX)
2. Add a sendonly video transceiver in `start()` with no track
3. Before `SetLocalDescription`, `mungeVideoSsrcsInOffer()` replaces the video m-line's auto-generated `StreamParams` with our pre-allocated SSRCs + SIM + FID groups
4. `UpdateLocalStreams_w()` in WebRTC's `channel.cc` sees SSRCs already present and skips generation
5. Later, `setVideoSource()` just calls `sender()->SetTrack()` — no renegotiation

### Video payload types are pinned, not negotiated

Group calls never negotiate payload types per pair: every client sends with the table `GroupInstanceCustomImpl::assignPayloadTypes` produces — VP8 100, VP9 102, H264 104, each followed by its RTX at +1 — and the SFU forwards RTP unchanged. PeerConnection's **receive** table comes from the LOCAL description (`VideoChannel::SetLocalContent_w`; the remote answer only syncs codec parameters by name), and `CreateOffer` numbers it by walking the platform factory's format list (96, 98, 100, ... with RTX at +1). On iOS that list is H264, H264, VP8, VP9, H265, so PT 104 was **H265**: a remote participant's H264 packets went to the H265 depacketizer, nothing decoded, and `VideoReceiveStream2` sat "active" (RTP timestamps advancing) logging `No decodable frame in 200ms requesting keyframe` forever. The host testbench never saw it because the builtin macOS factory lists five H264 profiles and lands one on PT 104 by luck.

`mungeVideoCodecsInOffer()` therefore rewrites the codec list of EVERY video m-line in every local offer (initial and renegotiation, outgoing and recvonly) to that table, copying each entry from the engine's own codec list (so feedback params stay what the engine supports; H264 = the constrained-baseline packetization-mode 1 entry, VP9 = profile 0) and dropping red/ulpfec/flexfec. The synthesized answer (`buildRemoteAnswer`) already speaks 104/105. Do not "clean this up" by removing the munge or by trusting `SetCodecPreferences` — preferences reorder but never renumber. The CLI reproduces the failure because `FakeInterface` now advertises formats in the iOS order (`--builtin-codec-order` restores the raw one): with the munge removed, `--participants 1 --reference-participants 1 --video` fails 1/2 pairs.

### Receiver video constraints must be CustomImpl's, byte for byte in shape (2026-09-22)

`sendReceiverVideoConstraints` used to send `minHeight = maxHeight` = 90/180/360, derived from
`maxQuality` alone, and no `onStageEndpoints`. The app requests `minQuality: .thumbnail` always and a
`.thumbnail` max for most grid tiles, so this engine routinely asked the SFU for `maxHeight 90`, below
the lowest simulcast layer (180). In a device log (2026-09-22) two endpoints re-requested this way
received **zero RTP** for 9 s and 48 s while every client-side step (transceiver, receive stream,
demuxer entries, sink proxy, constraints resent 3–4 times over a healthy data channel) was identical
to the earlier requests that worked — a frozen tile with nothing wrong on the client. The message is
now CustomImpl's (see "Colibri Data Channel Messages"), and it is logged whole
(`GroupRef: Sent ReceiverVideoConstraints {...}`) so the next such log shows exactly what was asked.
Causation on the production SFU is inferred, not measured: the log carried no requested qualities.
The CLI could not catch it: the Go SFU mapped heights on ReferenceImpl's own scale and the harness
always requested Full/Full. Regression: `--video-quality thumbnail` (the SFU now refuses a height
below 180) fails reference receivers on the old mapping and passes on the new.

### Incoming Video: SSRC-Based Demux

The answer for incoming video m-lines includes remote SSRCs from `VideoChannelDescription.ssrcGroups`. This is required because CustomImpl sets the `WebRTC-Video-DiscardPacketsWithUnknownSsrc` field trial process-wide, which disables unsignaled stream creation. Without explicit SSRCs, PeerConnection drops incoming video packets in mixed groups.

### Key Implementation Details

- **ICE roles**: PeerConnection uses standard ICE (full agent, controlling when remote is ICE-lite). The SFU uses `Accept` for PeerConnection clients vs `Dial` for CustomImpl clients.
- **Loopback**: `PeerConnectionFactory::Options::network_ignore_mask = 0` enables loopback interface gathering for localhost SFU
- **MID exclusion**: The `buildRemoteAnswer()` excludes the `urn:ietf:params:rtp-hdrext:sdes:mid` RTP header extension from ALL m-lines (audio and video). The SFU forwards raw RTP with the sender's MID value, which would cause the BUNDLE demuxer to route packets to the wrong channel. Without MID, PeerConnection falls back to SSRC/PT-based routing.
- **RTP header extensions**: Copied from the local offer per m-line (minus MID), ensuring BUNDLE-safe IDs. Hardcoding IDs risks collisions across the BUNDLE group.
- **SDP mid matching**: During renegotiation, the constructed remote answer mirrors the local offer's m-line structure and mids exactly. Mismatched mids cause `SetRemoteDescription` to fail.
- **Audio level reporting**: Uses synthetic levels (0.1) for all known remote SSRCs, since the SFU forwards RTP with extension IDs that may not match PeerConnection's negotiated mapping
- **Video sink wiring — never the app's sink, always the proxy**: the app hands `addIncomingVideoOutput` a `weak_ptr` because the tile's view owns the sink and is recreated on every quality switch. `AddOrUpdateSink` takes a raw pointer the track's `rtc::VideoBroadcaster` keeps until `RemoveSink`, so registering the app's sink directly was a use-after-free on the next decoded frame (crash in `rtc::VideoBroadcaster::OnFrame`, reproduced 2026-09-04 by "request full quality, switch back to medium"). Each endpoint therefore owns one `GRVideoSinkProxy` (`_videoSinkProxies`) — the only object ever registered on the receiver track — which locks each weak sink per frame and prunes dead ones, exactly CustomImpl's `VideoSinkImpl`. `attachVideoSinkProxy` registers it once the endpoint's track exists (`wirePendingVideoSinks()` after `SetRemoteDescription`, `onTrackAdded`, or immediately from `addIncomingVideoOutput`); `detachVideoSinkProxy` removes it on endpoint removal and `stop()`/destruction detach all before `Close()`. Several sinks per endpoint are normal (main view, clone, extra outputs). CLI regression: `--video-sink-churn`.
- **H264 codec in answer**: PT 104 (primary) + PT 105 (RTX, apt=104), matching CustomImpl's `assignPayloadTypes` table — and, since 2026-09-04, the LOCAL offer's video m-lines are munged to the same table (see "Video payload types are pinned, not negotiated"). RTCP feedback: nack, nack pli, ccm fir, goog-remb, transport-cc.
- **Renegotiation serialization**: Only one offer/answer cycle runs at a time, and none before the join response has been applied (`_isJoined`). Deferred renegotiations only fire if there are unnegotiated transceivers (no mid assigned yet), avoiding redundant cycles.
- **`setRequestedVideoChannels` is the full set, at any time**: it may arrive before the join response (the app's normal order) or before the data channel opens; the engine stores it, applies it in `onJoined()`, and replays the constraints on data-channel open. Never add a transceiver or renegotiate from it while `!_isJoined`.
- **Outgoing video arrives as a `VideoCaptureInterface`, not a source getter** (fixed 2026-09-06): the iOS wrapper only ever calls `setVideoCapture` (`requestVideo:` / `disableVideo:`) or sets `descriptor.videoCapture` at join; `descriptor.getVideoSource` is a CLI-only shortcut. Both paths now go through the shared `videoCaptureToGetVideoSource` (`VideoCaptureInterfaceImpl.h`) into `setVideoSource`, which also stores/clears `_getVideoSource` so a camera switched off before the join handshake completes is not re-attached by `addRemoteIceCandidates`. Before the fix `setVideoCapture` was an empty stub: the camera ran, the server marked the participant video-on, and no frame was ever encoded. CLI: `--video-via-capture` / `--video-via-capture-late`.
- **The engine owns "which endpoint is me"** (fixed 2026-09-06): the app hands over its full roster, itself included, both in `setRequestedVideoChannels` and in `addIncomingVideoOutput` for the local tile, and relies on the engine — which learns its own endpoint from the join response's `video.endpoint` — to (a) drop that entry before anything reaches the SFU (`remoteRequestedVideoChannels()`, used by `applyRequestedVideoChannels` and the data-channel replay) and (b) feed own-endpoint sinks from the camera preview (`_videoCapture->setOutput(proxy)`, `updateOwnPreviewOutput()`), exactly as CustomImpl does. Filter in `applyRequestedVideoChannels`, not at `setRequestedVideoChannels` entry: the app's first request precedes the join response. Before the fix the engine added a recvonly transceiver whose remote SSRCs were its OWN outgoing ones, renegotiated, and asked the SFU to loop its video back. CLI: `--request-own-video` (the SFU is asked afterwards, via `GoSfu_QueryRequestedLayer`, whether anyone requested itself).

### Known issue: host reference SENDER throttles

In the CLI, a ReferenceImpl participant's outgoing video reaches everyone (CustomImpl and ReferenceImpl receivers alike) at only ~1–3 fps after the first seconds — 41–65 frames in 30 s at 640x360 versus ~750 from CustomImpl senders — so group validation passes only because it requires ≥1 frame. Unrelated to the receive-side fixes above (a 30 s stock mixed run shows it with no sink churn); the likely cause is loopback BWE drift (the same ~80 kbps drift `group_participant.cpp` documents for CustomImpl) combined with `_minOutgoingVideoBitrateKbit` being stored but never applied in ReferenceImpl. Unverified on device. Measured 2026-09-04.

### Key Files
- `tgcalls/group/GroupInstanceReferenceImpl.h/.cpp` — implementation
- `tgcalls/group/GroupInstanceImpl.h` — shared `GroupInstanceInterface`

## Video Support Pitfalls

Critical findings from implementing video in the test SFU — relevant for anyone working on group video:

### H264 Decoder Requires Two Build Flags
The WebRTC BUILD needs BOTH `-DWEBRTC_USE_H264` (encoder, OpenH264) AND `-DWEBRTC_USE_H264_DECODER` (decoder, FFmpeg). Without the decoder flag, `H264Decoder::Create()` returns nullptr and WebRTC silently falls back to `NullVideoDecoder` which accepts frames but never decodes them — no error logged. The encoder works fine without the decoder flag, making this easy to miss.

### FFmpeg 7+ Removed `reordered_opaque`
`h264_decoder_impl.cc` uses `AVCodecContext::reordered_opaque` and `AVFrame::reordered_opaque` for passing timestamps through the decode pipeline. FFmpeg 7+ removed this field. The fix uses `AVPacket::pts` instead. IMPORTANT: `AVCodecContext::opaque` is already used to store the `H264DecoderImpl*` pointer (line 74 of `AVGetBuffer2`) — do NOT use it for timestamps.

### Outgoing Video Channel Steals Incoming RTP
`GroupInstanceCustomImpl` creates separate `cricket::VideoChannel` objects for outgoing and incoming video, all sharing the same `RtpTransport`. The outgoing channel's `WebRtcVideoReceiveChannel` has an "unsignalled SSRC" handler that creates default receive streams for unknown SSRCs. When video RTP from other participants arrives before `IncomingVideoChannel` registers its SSRCs, the outgoing channel intercepts the packets permanently. Fix: enable the `WebRTC-Video-DiscardPacketsWithUnknownSsrc` field trial in the field trial string.

### Video Channel Setup Is Reactive, Not Pre-Registered
Video channels are set up reactively when `ActiveVideoSsrcs` arrives via the data channel — same as the real Telegram app. The `dataChannelMessageReceived` callback in `GroupInstanceDescriptor` forwards Colibri messages to the app, which calls `setRequestedVideoChannels`. The `DiscardPacketsWithUnknownSsrc` field trial prevents the outgoing channel from stealing RTP packets for SSRCs not yet registered. The SFU sends proactive PLI after constraints arrive, ensuring keyframes are produced after the incoming channel is ready.

### SFU Must Send Proactive PLI
WebRTC's `VideoReceiveStream2` doesn't immediately request a keyframe when a new receive stream is created — it waits until it detects missing packets or a timeout. The SFU must proactively send PLI to the sender when a receiver first requests video via `ReceiverVideoConstraints`. Without this, the decoder waits indefinitely for a keyframe.

### RTP/RTCP Demux: Marker Bit False Positives
RFC 5761 demux by second byte: RTCP types are 200-211. But RTP with Marker=1 and dynamic PT ≥ 96 gives byte[1] ≥ 224. Using `byte[1] >= 200` falsely classifies H264 RTP (PT=104, M=1 → byte[1]=232) as RTCP. Correct range: `byte[1] >= 200 && byte[1] < 224`.

### SRTCP Requires Separate Contexts from SRTP
Pion's `SessionSRTP` and `SessionSRTCP` can't share the same `net.Conn` (both start read loops that fight for packets). The solution: demux RTCP at the transport level (in `PacketDemux`), create separate `srtp.Context` instances for SRTCP decrypt/encrypt using the same DTLS-extracted keys, and handle RTCP manually without `SessionSRTCP`.

### PeerConnection Simulcast SSRCs Require SDP Munging
PeerConnection's API doesn't support SSRC-based simulcast (only RID-based). With RID-based simulcast, SSRCs are NOT in the `createOffer` SDP — they're generated internally during `SetLocalDescription` and not accessible via `sender->GetParameters()` (only primary SSRCs, not RTX). The workaround: add a single-encoding transceiver (no RIDs), then replace the auto-generated `StreamParams` in the offer with pre-allocated SSRCs + SIM + FID groups before calling `SetLocalDescription`. `UpdateLocalStreams_w()` skips generation when SSRCs already exist. IMPORTANT: `transceiver->mid()` is `nullopt` before `SetLocalDescription` — match by content direction, not mid.

### MID RTP Header Extension Causes Wrong Channel Routing in SFU
The SFU forwards raw RTP packets including all header extensions. If the sender's video RTP includes a MID extension (e.g., MID="1"), the receiver's PeerConnection BUNDLE demuxer routes the packet to its own mid=1 channel — which is the outgoing video, not the incoming video transceiver. Fix: exclude `urn:ietf:params:rtp-hdrext:sdes:mid` from ALL m-lines in `buildRemoteAnswer()`. Without MID negotiated, PeerConnection falls back to SSRC/PT-based routing. This must be done for ALL m-lines (including audio) because the BUNDLE transport shares the extension map across all channels.

### `DiscardPacketsWithUnknownSsrc` Is Process-Wide
CustomImpl calls `field_trial::InitFieldTrialsFromString(...)` which sets `WebRTC-Video-DiscardPacketsWithUnknownSsrc/Enabled/` globally for the process. In mixed groups, this prevents ReferenceImpl's PeerConnection from creating unsignaled receive streams for incoming video. Fix: include explicit remote video SSRCs in the `buildRemoteAnswer()` for incoming video m-lines, so PeerConnection registers SSRC-based demux entries instead of relying on unsignaled stream handling.

### `OnTrack` Doesn't Fire for Locally-Created Recvonly Transceivers
When you call `AddTransceiver(MEDIA_TYPE_VIDEO, {direction=recvonly})`, PeerConnection creates the transceiver and its receiver track immediately. `OnTrack` only fires when a REMOTE-initiated track is added. For locally-created recvonly transceivers, you must wire sinks explicitly after `SetRemoteDescription` completes — don't wait for `OnTrack`.

### SSRC Parsing: json11 int_value() Overflows for uint32 > INT_MAX
`GoSfu_QueryVideoSsrcs` returns SSRCs as `uint32` in JSON. For values > 2^31, json11's `int_value()` (which returns `int`) overflows to `INT_MAX` (2147483647). Fix: use `number_value()` (returns `double`) and cast via `int64_t` to `uint32_t`.

### Join Payload JSON Field Name: `"sources"` Not `"ssrcs"`
tgcalls serializes video SSRC groups in `GroupJoinInternalPayload::serialize()` using the key `"sources"` (not `"ssrcs"`). The Go SFU's JSON struct tags must match: `Sources []int32 \`json:"sources"\``.

### Simulcast Max Layers Depends on Source Resolution, Not Bitrate
WebRTC's `kSimulcastFormats` table in `video/config/simulcast.cc` hardcodes `max_layers` per resolution: 640x360 → 2 layers, 960x540 → 3 layers, 1280x720 → 3 layers. The `SimulcastEncoderAdapter` uses this to cap the number of encoders regardless of available bitrate. If you need 3 simulcast layers, the source must be at least 960x540. The `FakeVideoTrackSource` uses 1280x720 for this reason. With 1280x720 and scale factors /4, /2, /1, the layers are 320x180, 640x360, 1280x720.

### SFU Must Rewrite SSRCs When Switching Simulcast Layers
CustomImpl's `IncomingVideoChannel` calls `SetSink(_mainVideoSsrc, ...)` where `_mainVideoSsrc` is the first SSRC in the SIM group (layer 0). The video sink only receives decoded frames from that specific SSRC's receive stream. When the SFU forwards a higher layer's packets, it must rewrite bytes 8-11 of the RTP header to the primary (layer 0) SSRC. RTX packets must similarly be rewritten to the layer 0 FID SSRC. Without this, higher-layer packets are delivered to the wrong receive stream and produce zero decoded frames. This is standard SFU behavior for simulcast — Jitsi and mediasoup do the same.

### Sender BWE Start Bitrate Determines Initial Layer Count
`adjustBitratePreferences` sets `start_bitrate_bps = max(min_bitrate_bps, 400k)`. At 400kbps start, the `BitrateAllocator` gives L0 (60k) + L1 (110k) = 170k, leaving only 230k for L2 which needs min 300k. Layer 2 is disabled until the GCC ramps up. The SFU's transport-cc feedback enables this ramp-up. The `UpdateAllocationLimits` log shows `total_requested_max_bitrate` — if this is below the sum of all layers' min bitrates, some layers are excluded.

### `assignPayloadTypes` Codec Ordering
WebRTC's `assignPayloadTypes` assigns dynamic PTs starting at 100 in order: VP8 (100/101), VP9 (102/103), H264 (104/105). Both sender and receiver call this independently with the same codec list, so PTs match. The SFU's join response codec PTs (100 for H264 in our case) are used by `configureVideoParams` to SELECT which codec to use, but the actual PT assignment comes from `assignPayloadTypes`.

## Known Issues
- `ThreadLocalObject::~ThreadLocalObject()` posts fire-and-forget cleanup tasks to the tgcalls media thread. If the process does orderly static destruction, the static thread pool may be torn down while these tasks are still executing, causing "pure virtual function called". The CLI tool uses `_exit()` to avoid this. This is not a problem in the real Telegram app.
- `SignalingSctpConnection::OnReadyToSend()` had a missing `break` after the first send failure in its pending-data flush loop. This could cause application-level message reordering (though the application handles it gracefully via `_pendingIceCandidates` buffering). Fixed in our fork.
- `InstanceV2ReferenceImpl::writeStateLogRecords()` had a use-after-free: it captured a raw `Call*` pointer on the media thread and posted it to the worker thread. If `stop()` called `_peerConnection->Close()` (which destroys `Call`) between the post and worker thread execution, the worker thread would dereference a dangling pointer. The `call_ptr_` field in WebRTC's `PeerConnection` is `Call* const` and is never nulled, so the existing null check didn't catch this. Fixed with an `_isStopped` atomic flag checked in the worker thread lambda before accessing `call`. Manifested as ~2% segfault rate under 250-process parallel load; 100% pass rate after fix (5000/5000).
- WebRTC's `RTC_LOG` writes to stdout, not stderr. There is no way to separate it from application output within a single process. The local mass test harness (`run-local-test.sh`) works around this by using separate processes and checking exit codes rather than parsing output.
