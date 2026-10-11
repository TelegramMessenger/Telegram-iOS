# tgcalls 14.0.0: CompatImpl speaks the 13.0.0 channel protocol

Date: 2026-10-11. Status: implemented and verified (see Results); uncommitted.

## Problem

`InstanceV2CompatImpl` (call version 14.0.0) drives a WebRTC PeerConnection and is
meant to interoperate with `InstanceV2Impl` (7.0.0-13.0.0) over that engine's
signaling. Measured on 2026-10-11 it carries two-way media in no pairing:

| caller -> callee | outcome |
|---|---|
| 14 <-> 14 | only the caller sends; data channel never opens; the second answer fails (BUNDLE) |
| 14 <-> 14 `--video` | the first answer fails (`Failed to set up audio demuxing`) |
| 14 -> 13 | one audio sender; the same BUNDLE failure |
| 13 -> 14 | no media at all (exit 1, 0/6 under loss) |

`SignalingTranslator` modelled the exchange as one JSEP offer/answer per call,
with the caller always offering. The 13.0.0 protocol is different, and every
defect follows from the mismatch.

## The 13.0.0 protocol (ContentNegotiation.cpp, InstanceV2Impl.cpp)

- `InitialSetup {ufrag, pwd, renomination, fingerprints[{hash, fingerprint, setup}]}`.
  The caller sends it at start with `setup = actpass`; the callee answers every
  InitialSetup it receives with its own, `setup = passive`. Each one received is
  applied (`setRemoteParams`), so credentials may change mid-call.
- `NegotiateChannels {exchangeId, contents}`. Media is a set of one-way
  channels. **An offer lists the sender's own outgoing channels, the complete
  set** (the receiver replaces its incoming set with it). **An answer echoes the
  offer's exchangeId** and lists the offerer's channels it accepted (offerer's
  ssrc, answerer's codec choice). Each side offers its own channels; the callee
  answers the caller's first offer and then offers its own.
- A message is an answer iff a local offer is pending and the exchangeId
  matches; anything else is an offer. On glare the caller ignores the remote
  offer and the callee drops its own and answers.
- The data channel is not negotiated: SCTP on port 5000 over the same DTLS (or
  mtproto) transport, max message 262144, stream 0, caller opens with DCEP,
  callee acks. 13.0.0 sends `MediaState` **only** on it, and feeds every
  data-channel text message into its signaling parser.
- DTLS: the caller is the client, the callee the server.

## Design

CompatImpl becomes a 13.0.0-protocol endpoint whose media engine happens to be
a PeerConnection. Its PeerConnection negotiates against a remote description
synthesised by the translator; the two PeerConnections of a 14 <-> 14 call never
see each other's SDP, only the wire (ICE, DTLS, RTP by SSRC, SCTP).

### Local side

- Outgoing audio is a `kSendOnly` transceiver. Outgoing video is one `kSendOnly`
  transceiver created on the first camera; later cameras `SetTrack` on it and
  camera-off sets it `kInactive` with no track (no m-line growth, and an
  inactive channel drops out of the next offer, which is how 13.0.0 removes
  one).
- Remote channels get the `kRecvOnly` transceivers PeerConnection creates when
  it applies a remote offer. Our own `AddTransceiver` transceivers are never
  associated with them (`created_by_addtrack` is false), which is wanted here.
- The caller creates the `"data"` channel (DCEP opener, sid 0 as DTLS client);
  the callee receives it through `OnDataChannel`.

### Translator

State: the latest remote InitialSetup; the pending local offer's exchangeId and
the ids of earlier ones (a late answer to a superseded offer is dropped, not
mistaken for an offer); for each remote channel, a synthesised mid
(`r<ssrc>`), its last content, and whether the last remote offer still lists
it; for each of our ssrcs, the content the remote accepted.

Outbound:
- `InitialSetup` with the local ICE credentials and fingerprint, `setup` fixed by
  role exactly as 13.0.0 (`actpass` caller, `passive` callee). Sent before a
  NegotiateChannels whenever the credentials or fingerprint changed (first
  exchange, ICE restart on either side).
- Offer: our `kSendOnly` sections that carry an ssrc, fresh random exchangeId.
- Answer: our accepted (`kRecvOnly`) sections for remote channels, ssrc and
  ssrc-groups taken from the remote offer, the remote offer's exchangeId.

Inbound remote description, both kinds:
- m-line order follows our local description (the current one for a remote
  offer, the pending offer for a remote answer); new remote channels are
  appended to a remote offer.
- Remote channel sections: `kSendOnly` with the content if the remote still
  offers it, else `kInactive` without streams.
- Our sections: `kRecvOnly` with the codecs the remote accepted (the answer's
  for this exchange, the last accepted ones in a remote offer, else our own),
  no streams (ssrc 0 must never be signalled); `kInactive` when we do not send.
- The application section is always present and accepted (port 5000, max
  262144); a remote offer before any local description adds one (mid `d`).
- Rejected local sections stay rejected and leave the BUNDLE group.
- The `sdes:mid`, `rtp-stream-id` and `repaired-rtp-stream-id` header
  extensions are stripped everywhere: mids are local to each side, and the
  demuxer drops RTP carrying a MID it does not know.
- DTLS `setup`: the remote is `active` when we are the callee and `passive`
  when we are the caller, whatever the InitialSetup says, so the roles never
  move after the first exchange (13.0.0 would change its role on a mid-call
  `actpass`).

### Engine

- InitialSetup is applied on receipt (it is the peer's current ICE agent).
  The first design queued it in order with NegotiateChannels, and 14 -> 13
  deadlocked: 13.0.0 sends its InitialSetup asynchronously, after the answer
  and offer that need it.
- Receiving NegotiateChannels: classified on receipt (an answer clears the
  pending offer there), then applied one at a time while no SetLocal/Remote
  Description is in flight and no answer is owed; held until the first
  InitialSetup. An answer to the pending offer is applied as a remote answer. Anything else is an
  offer: ignored by the caller while its own offer is pending (13.0.0's rule);
  the callee rolls its own offer back (implicit rollback), answers, and offers
  again afterwards.
- Either side offers (`onRenegotiationNeeded`, capture changes, ICE restart,
  an unassociated transceiver after a rollback), from a quiet stable state
  only; the callee not before the first remote offer, and the caller not
  before the callee's first offer (up to 10 s). Without that hold, at 30%
  signaling loss a 13.0.0 callee's first offer (its audio) took 5.6 s, crossed
  the caller's camera offer, was ignored under caller-wins, and 13.0.0 never
  re-offered: one-way audio.
- A failed remote answer rolls our offer back; a failed local answer rolls the
  remote offer back; automatic re-offers stop after 3 consecutive failures.
- Data-channel text messages go through the signaling parser, so 13.0.0's
  MediaState arrives. MediaState is still sent over signaling, which 13.0.0
  also accepts.

## Out of scope / consequences

- A 14.0.0 build from before this change cannot interoperate with one after it,
  and the mix is worse than old <-> old: an old callee's answer carries its
  counter (exchangeId 0), a new caller classifies it as an offer and ignores it
  as glare, and stays in have-local-offer with no media either way; an old
  caller never applies a new callee's offer. Both are 14.0.0 on the wire, so a
  server serving 14.0.0 during a rollout would pair them. Bumping the version
  string, or not serving 14.0.0 until old builds are gone, is a server/app
  decision.
- 13.0.0's own glare bug (its callee drops its offer and never re-offers) is not
  ours to fix; CompatImpl avoids triggering it by not re-offering after the
  first exchange unless it has to.

## Verification

`tgcalls_cli` p2p for 14<->14, 14->13, 13->14, each with and without `--video`,
`network_use_mtproto` on both, and `--drop-rate 0.3 --delay 50-200` repeated.
Pass means: two distinct audio send SSRCs, each received with a signalled
receive stream, zero failed descriptions, the data channel open on both ends
(OPEN_ACK), MediaState received both ways, and for `--video` two video send
streams. Controls 11<->11 and 13<->13 unchanged. Then the full
`debug_sim_arm64` app build.

## Results (2026-10-11)

Before: 14 <-> 14 one-way audio, no data channel, failed descriptions; 13 -> 14
no media at all. After, 8 runs per row unless noted:

| scenario | 14<->14 | 14->13 | 13->14 |
|---|---|---|---|
| plain, `--video`, `--video-late` (single runs) | healthy | healthy | healthy |
| `network_use_mtproto` both ends, plain and `--video-late` | healthy, 0 DTLS handshakes | healthy | healthy |
| `--delay 100-300`, `--video` and `--video-late` | 8/8 | 8/8 | 8/8 |
| 30% loss, audio-only / `--video` | not run / 8/8 | 8/8 / 8/8 | 8/8 / 8/8 |
| 30% loss, `--video-late` | 8/8 | 5/8 | 8/8 |

"Healthy": two audio send SSRCs, two signalled audio receive streams, no failed
description, the data channel open (OPEN_ACK), MediaState and decoded video
frames both ways. The 14 -> 13 lossy `--video-late` failures are each exactly one
glare-ignored 13.0.0 offer (caller-wins): its camera is not negotiated until it
changes again. 13 <-> 13 scores the same 5/8 in that scenario, so this is
13.0.0's protocol, not the translator. Not exercised: the caller's ICE restart,
including the credential-change InitialSetup re-send (one InitialSetup per side
in every run).
