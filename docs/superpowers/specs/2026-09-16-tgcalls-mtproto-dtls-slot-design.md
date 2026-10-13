# tgcalls: mtproto in the DTLS slot, seam-only webrtc patches

Date: 2026-09-16. Status: approved design, not yet implemented.
Supersedes the same-day "mtproto SCTP demux" record, whose findings are folded
into the Background section.

## Goal

`network_use_mtproto` on the PeerConnection engines (call versions 11.0.0,
18.0.0, 19.0.0) must mean full mtproto and zero DTLS: the shared secret exists
before the call starts, so the DTLS handshake is pure overhead, and the wire
bytes must stay identical to 13.0.0 (`mtproto(RTP)` for media,
`mtproto(0xdcdcdcdc || SCTP)` for the data channel) so an A/B isolates the
engine. The vendored webrtc fork may carry **seam-only** patches: additive
injection points and options, default-off, that change nothing for a caller
that does not opt in. It may not carry behaviour patches in transport or SDP
code.

Group calls (`GroupInstanceReferenceImpl`) keep DTLS-SRTP and need to notice
an audio SSRC the demuxer drops, so a participant who unmutes mid-call is
heard. That discovery must not require inspecting every packet.

## Background

The 2026-09-01 implementation used `PeerConnectionFactoryInterface::Options::
disable_encryption` to obtain a plain `RtpTransport`, and an ICE-level
decorator (`MtProtoIceTransport`, injected through `ice_transport_factory`)
to apply mtproto below the now-inactive `DtlsTransport`. `disable_encryption`
also turns off certificates, fingerprints and the SCTP factory, and each of
those had to be put back with a behaviour patch in the fork:

| Patch | File | What it forced back |
|---|---|---|
| "Allow SCTP without DTLS", transport half | `pc/peer_connection.cc` | SCTP factory created with DTLS off |
| "Allow SCTP without DTLS", SDP half | `pc/media_session.cc` | answer accepts `UDP/DTLS/SCTP` on a fingerprint-less transport |
| "Inactive DtlsTransport forwards packet flags" | `p2p/base/dtls_transport.cc` | SCTP/RTP distinction survives the inactive DTLS layer |

The second and third were added on 2026-09-16 after a large-scale A/B showed
the mtproto arm performing worse than plain 11.0.0. Root causes found that
day, all reproduced:

1. **Renegotiation storm (dominant).** Without the SDP half, every answer
   rejected the data section; the offerer tore the data-channel transport
   down; `CheckIfNegotiationIsNeeded` saw a used data channel with no
   negotiated m-section; both peers renegotiated continuously. 6 s loopback:
   4,765 `SetLocalDescription` on 11.0.0, 568 on 18.0.0, 96 on 19.0.0 versus
   4 for a plain call; the audio channel flapped send/recv each cycle; the
   data channel never opened; in production each cycle is an offer and an
   answer through the signaling server.
2. **Send return value.** The decorator returned the ciphertext length.
   `RtpTransport::SendPacket` treats a length mismatch as failure and reads
   the ICE channel's never-cleared last error; after one genuine ENOTCONN
   every later successful send dropped ready-to-send and paused the pacer.
3. **RTP parsed as SCTP.** Stock inactive `DtlsTransport` forces `flags == 0`
   on receive; `DcSctpTransport` only skips non-zero flags; every media packet
   was CRC-checked by dcsctp and logged as an error. Masked at runtime by (1),
   which destroyed the SCTP transport within milliseconds; 728 error lines in
   6 s once (1) was fixed.

The decorator also acquired a second job: with no key it is a pass-through
whose `IncomingPacketObserver` lets the group engine read SSRCs from raw RTP,
because after the first renegotiation payload-type demuxing is disabled and
an unknown SSRC never reaches a receive stream or frame transformer.

Two upstream seams were unused: `JsepTransportController::Config::
dtls_transport_factory` exists but is not reachable from
`PeerConnectionDependencies`; and `RtpTransport` already reports every demux
failure to `PeerConnection`, which forwards it only to bandwidth estimation.

## Design

### Layering

```
RtpTransport (plain)            DcSctpTransport
        \                          /
         MtProtoDtlsTransport   tgcalls; DTLS slot; framing + encryption; no handshake
                    |
          P2PTransportChannel   stock; STUN stays cleartext for reflectors
```

Group calls keep stock `DtlsTransport` and DTLS-SRTP; SSRC discovery moves to
an observer callback. `MtProtoIceTransport`, its factory and its test are
deleted. The three behaviour patches are reverted.

### Seams in the vendored webrtc

All additive, default-off, each marked `TGCALLS SEAM` with the consuming
tgcalls class named, so a webrtc bump knows what to carry and can drop a seam
when upstream grows an equivalent.

1. **`PeerConnectionDependencies::dtls_transport_factory`**
   (`std::unique_ptr<cricket::DtlsTransportFactory>`). `PeerConnection`
   stores it and sets `config.dtls_transport_factory`, which
   `JsepTransportController::CreateDtlsTransport` already consults.
2. **`PeerConnectionFactoryInterface::Options::external_transport_security`**
   (`bool`). In `PeerConnection`: `config.disable_encryption =
   options_.disable_encryption || options_.external_transport_security`, so
   the controller builds the plain `RtpTransport`; `SrtpRequired()` returns
   `dtls_enabled_ && !options_.external_transport_security`, so `BaseChannel`
   sends without SRTP. `DtlsEnabled()` is untouched: certificate generation,
   fingerprints, `a=setup`, the SCTP factory and SDP negotiation stay stock.
3. **`PeerConnectionObserver::OnUnDemuxableRtpPacket(const RtpPacketReceived&)`**,
   default empty, called on the network thread inside
   `PeerConnection::InitializeUnDemuxablePacketHandler` before the existing
   post to the worker thread.

### `MtProtoDtlsTransport` (tgcalls `v2/MtProtoDtlsTransport.{h,cpp}`)

A `cricket::DtlsTransportInternal` constructed with the ICE transport and the
`EncryptionKey`, created by `MtProtoDtlsTransportFactory`. The factory and the
option are installed together, from the single `_useMtProto` decision, in
`InstanceV2ReferenceImpl::start` and `CallCoreHost::executePcCreate`; the
option without the factory yields a stock inactive DTLS transport over plain
RTP, which connects nothing.

- **State.** `dtls_state()` starts `kNew` and becomes `kConnected` the first
  time the ICE transport reports writable; it never reports `kFailed` or
  `kClosed` (stock `DtlsTransport` emits nothing from its destructor either;
  the `webrtc::DtlsTransport` wrapper handles teardown via `Clear()`). The one
  transition is published with `SendDtlsState`, so the
  aggregate `PeerConnectionState` and the `webrtc::DtlsTransport` stats
  wrapper see a connected transport. `IsDtlsActive()` is true.
- **Negotiation surface.** `SetDtlsRole`/`GetDtlsRole` store the role;
  `SetLocalCertificate`/`GetLocalCertificate` store the certificate the
  controller hands over (its fingerprint appears in the SDP and is otherwise
  unused); `SetRemoteParameters` stores and returns OK; `GetSrtpCryptoSuite`,
  `GetSslCipherSuite`, `GetSslVersionBytes`, `ExportKeyingMaterial` return
  false; `GetSslPeerSignatureAlgorithm` returns 0; `GetRemoteSSLCertChain`
  returns null.
- **Send.** `flags` is ground truth, as in 13.0.0's `MtProtoPacketTransport`:
  non-zero (`PF_SRTP_BYPASS` from `BaseChannel` for RTP and RTCP) is framed
  bare, zero (SCTP from `DcSctpTransport`) gets the `0xdcdcdcdc` prefix; then
  `EncryptedConnection` transport-mode encryption; then ICE `SendPacket` with
  flags 0 (the channel rejects non-zero). Returns the caller's length on
  success, the ICE result when negative, -1 if encryption fails.
- **Receive.** Decrypt with `EncryptedConnection::handleIncomingRawPacket`;
  emit each contained message: prefix present means `flags 0`, absent means
  `PF_SRTP_BYPASS`. `RtpTransport` ignores flags; `DcSctpTransport` skips
  non-zero, so RTP never enters the SCTP parser. Undecryptable packets emit
  nothing; `EncryptedConnection` logs `ERROR! Bad incoming data hash.` once per
  such packet, as in 13.0.0.
- **Signals.** Forward the seven `PacketTransportInternal` signals from ICE
  (writable, receiving, ready-to-send, sent, network route, closed, read
  packet) re-emitted with `this`, mirroring stock `DtlsTransport`. There are
  no ICE-level signals or callbacks to bridge, which removes the 11-bridge
  fragility of the current decorator.
- **Options.** `SetOption`, `GetOption`, `GetError`, `network_route`,
  `transport_name`, `component`, `writable`, `receiving`, `ice_transport`
  forward to ICE.

### Group-call SSRC discovery

`GroupInstanceReferenceImpl`'s `PeerConnectionObserver` adapter implements
`OnUnDemuxableRtpPacket`. On the network thread it applies the filter the
decorator tap applies today: Opus payload type, non-zero SSRC, the dedupe set
that degrades to reporting everything when full, and the keep-reporting rule
while E2E is on and the sender is unknown. It then posts
`handleDiscoveredAudioSsrc` to the media thread. The packet arrives parsed and
SRTP-unprotected, so the hand-rolled header reads go. The mid=0 catch-all
frame transformer is unchanged: packets it receives were demuxed and never
reach the hook. The group engine no longer sets `ice_transport_factory`.

### Invariants

- Option and factory travel together (one boolean in each engine).
- `flags` is read at exactly two points, the two framing decisions; nothing
  else in the transport inspects or rewrites it.
- No ICE-level state is mirrored into the transport; `writable()` and friends
  are forwards.
- STUN never passes through the transport: ICE's own binding requests are
  issued below it, so reflectors keep parsing them.

## Testing

- The host `cc_test` becomes `//submodules/TgVoipWebrtc:mtproto_dtls_transport_test`
  (`tgcalls/v2/MtProtoDtlsTransportTest.cpp`, listed explicitly in the BUILD
  and excluded in `tgcalls/Package.swift`). The fake ICE transport stays.
  Stacks are `MtProtoDtlsTransport` under a real `webrtc::RtpTransport` and a
  real `webrtc::DcSctpTransport`. Carried over: send returns the caller's
  length; a stale ENOTCONN does not drop ready-to-send after a successful
  send; RTP does not reach SCTP (zero `PARSE_FAILED`); SCTP frames reach the
  SCTP subscriber with flags 0; flags follow framing in both directions. New:
  state becomes connected on ICE writable and is published through
  `SubscribeDtlsTransportState`; certificate and remote parameters
  round-trip; the pass-through/observer tests are removed with the decorator.
- `tgcalls_cli --mode p2p --duration 6 --version {11.0.0,18.0.0,19.0.0}
  --custom-params '{"network_use_mtproto":true}' --custom-params2 '{"network_use_mtproto":true}'
  --log-file …` must show: `Rejected data channel transport` 0,
  `SetLocalDescription` 4, `OPEN_ACK` 1, `PARSE_FAILED` 0,
  `Creating DtlsSrtpTransport` 0, zero DTLS handshake lines, and a log about
  the size of a plain call (~750 lines). Plain calls unchanged (~830 lines,
  `OPEN_ACK` 1).
- `tgcalls_cli --mode group --unmute-after …` keeps scoring 2/2, the check
  that pinned the original discovery bug.
- Full `Make.py build` for `debug_sim_arm64`.

## Rollout

Four commits: tgcalls (transport, factory, engines, tests, CLAUDE.md), webrtc
(revert the three behaviour patches, add the three seams), tgcalls group
engine (hook, remove the decorator), telegram-ios (pointer bumps, BUILD,
TgVoipWebrtc CLAUDE.md, this spec). `network_use_mtproto` stays default-off,
so production is unaffected until the A/B is re-run; the group reference
engine stays behind its Debug Settings switch. Both CLAUDE.md files lose the
"mutual filtering" and "inactive DtlsTransport" invariants and gain the seam
list.

## Out of scope

The unexplained report that 18/19 perform worse than 11 with mtproto off.
Plain loopback calls on 18 and 19 are clean and identical in shape to 11;
the only 18/19-specific non-mtproto change in the 2026-09-01 bump was the
duplicate-offer guard. Needs the observed signal from the A/B.
