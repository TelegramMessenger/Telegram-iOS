# mtproto in the DTLS slot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the ICE-level `MtProtoIceTransport` decorator and the three behaviour patches in the vendored webrtc with a tgcalls `MtProtoDtlsTransport` in the DTLS slot, three additive webrtc seams, and un-demuxable-packet SSRC discovery for group calls.

**Architecture:** WebRTC gains three default-off seams (`PeerConnectionDependencies::dtls_transport_factory`, `Options::external_transport_security`, `PeerConnectionObserver::OnUnDemuxableRtpPacket`). tgcalls provides a no-handshake `cricket::DtlsTransportInternal` that frames from `flags` (bypass = RTP, 0 = SCTP with `0xdcdcdcdc` prefix), encrypts with `EncryptedConnection`, and reports connected when ICE is writable. Call versions 11/18/19 install the option and the factory together under `network_use_mtproto`; the group reference engine reads dropped SSRCs from the observer hook.

**Tech Stack:** C++17, vendored webrtc (git submodule at `third-party/webrtc/webrtc`), tgcalls (git submodule at `submodules/TgVoipWebrtc/tgcalls`), Bazel 9.2.0 (`./build-input/bazel-9.2.0-darwin-arm64`), host `cc_test` with the `CHECK_TRUE` + `main()` pattern, `tgcalls_cli` loopback testbench.

**Spec:** `docs/superpowers/specs/2026-09-16-tgcalls-mtproto-dtls-slot-design.md`

## Global Constraints

- Full mtproto and zero DTLS on the wire for 11/18/19: no DTLS handshake packets, wire bytes identical to 13.0.0 (`mtproto(RTP)`, `mtproto(0xdcdcdcdc || SCTP)`).
- Vendored webrtc may carry **seam-only** patches: additive, default-off, no behaviour change for a caller that does not opt in. Every seam is marked `TGCALLS SEAM (<tgcalls consumer>)`.
- `SendPacket` on the tgcalls transport returns the caller's byte count on success.
- `flags` is read at exactly two points (send framing, receive framing) and never rewritten elsewhere.
- Option and factory are installed together from one boolean per engine.
- `network_use_mtproto` stays default-off; the group reference engine stays behind its Debug Settings switch.
- Three repositories are involved. Paths below are relative to `/Users/isaac/build/telegram/telegram-ios` unless marked `[webrtc]` (`third-party/webrtc/webrtc`) or `[tgcalls]` (`submodules/TgVoipWebrtc/tgcalls`). Commit in the repository that owns the file.
- Commit messages end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Bazel runs from the telegram-ios root: `./build-input/bazel-9.2.0-darwin-arm64`.

---

## File map

| Repo | File | Responsibility |
|---|---|---|
| webrtc | `api/peer_connection_interface.h` | Seams 1–3: dependency field, option, observer callback |
| webrtc | `pc/peer_connection.h`, `pc/peer_connection.cc` | Plumb the factory and option; call the observer hook; restore stock SCTP gate |
| webrtc | `pc/media_session.cc`, `p2p/base/dtls_transport.cc` | Revert to stock (uncommitted behaviour patches) |
| tgcalls | `tgcalls/v2/MtProtoDtlsTransport.h/.cpp` | The no-handshake DTLS-slot transport + factory |
| tgcalls | `tgcalls/v2/MtProtoDtlsTransportTest.cpp` | Host test (renamed from `MtProtoIceTransportTest.cpp`) |
| tgcalls | `tgcalls/v2/InstanceV2ReferenceImpl.cpp`, `tgcalls/v2wasm/CallCoreHost.cpp` | Install option + factory |
| tgcalls | `tgcalls/group/GroupInstanceReferenceImpl.cpp` | SSRC discovery via `OnUnDemuxableRtpPacket` |
| tgcalls | `tgcalls/v2/MtProtoIceTransport.h/.cpp` | Deleted |
| tgcalls | `CLAUDE.md`, `Package.swift` | Docs; SwiftPM exclude for the test |
| telegram-ios | `submodules/TgVoipWebrtc/BUILD`, `submodules/TgVoipWebrtc/CLAUDE.md` | Source lists, test target, seam docs |

---

### Task 1: webrtc seams (revert behaviour patches, add three additive seams)

**Files:**
- Modify `[webrtc] api/peer_connection_interface.h`
- Modify `[webrtc] pc/peer_connection.h`
- Modify `[webrtc] pc/peer_connection.cc`
- Revert `[webrtc] pc/media_session.cc`, `[webrtc] p2p/base/dtls_transport.cc`

**Interfaces:**
- Produces: `webrtc::PeerConnectionDependencies::dtls_transport_factory` (`std::unique_ptr<cricket::DtlsTransportFactory>`); `webrtc::PeerConnectionFactoryInterface::Options::external_transport_security` (`bool`, default `false`); `virtual void webrtc::PeerConnectionObserver::OnUnDemuxableRtpPacket(const RtpPacketReceived& packet) {}`.

- [ ] **Step 1: Revert the two uncommitted behaviour patches**

```bash
cd /Users/isaac/build/telegram/telegram-ios/third-party/webrtc/webrtc
git checkout -- pc/media_session.cc p2p/base/dtls_transport.cc
git status --short   # expect: nothing listed for those two files
```

- [ ] **Step 2: Restore the stock SCTP gate in `pc/peer_connection.cc`**

In `PeerConnection::InitializeTransportController_n`, replace the block that begins `// TGCALLS PATCH: SCTP no longer requires DTLS.` and ends with `config.sctp_factory = context_->sctp_transport_factory();` with the upstream text:

```cpp
  // DTLS has to be enabled to use SCTP.
  if (dtls_enabled_) {
    config.sctp_factory = context_->sctp_transport_factory();
  }
```

Verify: `grep -n "TGCALLS PATCH" pc/peer_connection.cc` prints nothing.

- [ ] **Step 3: Add the three seams to `api/peer_connection_interface.h`**

(a) Next to `#include "p2p/base/port_allocator.h"` add:

```cpp
#include "p2p/base/dtls_transport_factory.h"
```

(b) Immediately after the first `namespace webrtc {` line add the forward declaration:

```cpp
class RtpPacketReceived;
```

(c) In `PeerConnectionFactoryInterface::Options`, directly after `bool disable_encryption = false;` add:

```cpp
    // TGCALLS SEAM (tgcalls::MtProtoDtlsTransport): transport security is
    // supplied below this stack by an external layer. Selects the plain
    // RtpTransport (no SRTP) and drops BaseChannel's SRTP requirement, but
    // leaves DTLS *enabled*: certificates, fingerprints, the SCTP factory and
    // SDP negotiation stay stock. Pair it with
    // PeerConnectionDependencies::dtls_transport_factory supplying a
    // DtlsTransportInternal that performs no handshake. Default off: nothing
    // changes for a caller that does not set it.
    bool external_transport_security = false;
```

(d) In `PeerConnectionObserver`, directly after `virtual void OnInterestingUsage(int usage_pattern) {}` add:

```cpp
  // TGCALLS SEAM (tgcalls::GroupInstanceReferenceImpl): an RTP packet the
  // transport could not demux (no MID, SSRC or payload-type binding). Called
  // on the network thread, after SRTP unprotect, before the packet is handed
  // to Call for bandwidth estimation. Default no-op.
  virtual void OnUnDemuxableRtpPacket(const RtpPacketReceived& packet) {}
```

(e) In `PeerConnectionDependencies`, directly after `std::unique_ptr<webrtc::IceTransportFactory> ice_transport_factory;` add:

```cpp
  // TGCALLS SEAM (tgcalls::MtProtoDtlsTransportFactory): plumbs the factory
  // that JsepTransportController::Config already accepts. Null means the
  // stock cricket::DtlsTransport.
  std::unique_ptr<cricket::DtlsTransportFactory> dtls_transport_factory;
```

- [ ] **Step 4: Plumb the factory and the observer through `pc/peer_connection.h`**

Directly after the `ice_transport_factory_` member (the `const std::unique_ptr<IceTransportFactory> ice_transport_factory_;` declaration with its trailing comment) add:

```cpp
  // TGCALLS SEAM: see PeerConnectionDependencies::dtls_transport_factory.
  const std::unique_ptr<cricket::DtlsTransportFactory> dtls_transport_factory_;
```

Change the declaration

```cpp
  std::function<void(const RtpPacketReceived& parsed_packet)>
  InitializeUnDemuxablePacketHandler();
```

to

```cpp
  std::function<void(const RtpPacketReceived& parsed_packet)>
  InitializeUnDemuxablePacketHandler(PeerConnectionObserver* observer);
```

- [ ] **Step 5: Wire the seams in `pc/peer_connection.cc`**

(a) In the constructor initialiser list, directly after
`ice_transport_factory_(std::move(dependencies.ice_transport_factory)),` add:

```cpp
      dtls_transport_factory_(std::move(dependencies.dtls_transport_factory)),
```

(b) In `InitializeTransportController_n`, replace
`config.disable_encryption = options_.disable_encryption;` with:

```cpp
  // TGCALLS SEAM (Options::external_transport_security): the plain
  // RtpTransport without turning DTLS off at the PeerConnection level.
  config.disable_encryption =
      options_.disable_encryption || options_.external_transport_security;
```

(c) In the same function, replace
`config.un_demuxable_packet_handler = InitializeUnDemuxablePacketHandler();` with:

```cpp
  config.un_demuxable_packet_handler =
      InitializeUnDemuxablePacketHandler(dependencies.observer);
```

(d) In the same function, directly after `config.ice_transport_factory = ice_transport_factory_.get();` add:

```cpp
  // TGCALLS SEAM: null keeps the stock cricket::DtlsTransport.
  config.dtls_transport_factory = dtls_transport_factory_.get();
```

(e) Replace the body of `PeerConnection::SrtpRequired()`:

```cpp
bool PeerConnection::SrtpRequired() const {
  RTC_DCHECK_RUN_ON(signaling_thread());
  // TGCALLS SEAM (Options::external_transport_security): SRTP is not required
  // when an external layer secures the transport; DTLS stays enabled for SDP.
  return dtls_enabled_ && !options_.external_transport_security;
}
```

(f) Replace `PeerConnection::InitializeUnDemuxablePacketHandler` with:

```cpp
std::function<void(const RtpPacketReceived& parsed_packet)>
PeerConnection::InitializeUnDemuxablePacketHandler(
    PeerConnectionObserver* observer) {
  RTC_DCHECK_RUN_ON(network_thread());
  return [this, observer](const RtpPacketReceived& parsed_packet) {
    // TGCALLS SEAM (PeerConnectionObserver::OnUnDemuxableRtpPacket): the
    // observer outlives this PeerConnection by API contract, and Close()
    // destroys the transport controller before clearing the observer, so no
    // packet can reach here afterwards. Network thread, per dropped packet.
    if (observer) {
      observer->OnUnDemuxableRtpPacket(parsed_packet);
    }
    worker_thread()->PostTask(
        SafeTask(worker_thread_safety_, [this, parsed_packet]() {
          // Deliver the packet anyway to Call to allow Call to do BWE.
          // Even if there is no media receiver, the packet has still
          // been received on the network and has been correcly parsed.
          call_ptr_->Receiver()->DeliverRtpPacket(
              MediaType::ANY, parsed_packet,
              /*undemuxable_packet_handler=*/
              [](const RtpPacketReceived& packet) { return false; });
        }));
  };
}
```

- [ ] **Step 6: Compile webrtc for the host**

```bash
cd /Users/isaac/build/telegram/telegram-ios
./build-input/bazel-9.2.0-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli 2>&1 | grep -E "error:|Build completed"
```

Expected: build fails only in tgcalls (`MtProtoIceTransport.cpp` still compiles; nothing else references the removed patches), or `Build completed successfully`. Any error inside `third-party/webrtc` must be fixed before continuing.

- [ ] **Step 7: Commit in the webrtc submodule**

```bash
cd /Users/isaac/build/telegram/telegram-ios/third-party/webrtc/webrtc
git add api/peer_connection_interface.h pc/peer_connection.h pc/peer_connection.cc
git commit -m "Replace the SCTP-without-DTLS patch with three tgcalls seams

Reverts the behaviour patch that created the SCTP factory with DTLS off, and
adds three additive, default-off seams: PeerConnectionDependencies::
dtls_transport_factory (plumbed to JsepTransportController::Config),
Options::external_transport_security (plain RtpTransport and no SRTP
requirement while DTLS stays enabled for SDP), and
PeerConnectionObserver::OnUnDemuxableRtpPacket (network thread, before the
existing hand-off to Call). tgcalls supplies a no-handshake DtlsTransportInternal
through the factory; see telegram-ios docs/superpowers/specs/
2026-09-16-tgcalls-mtproto-dtls-slot-design.md.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: `MtProtoDtlsTransport` with its host test

**Files:**
- Create `[tgcalls] tgcalls/v2/MtProtoDtlsTransport.h`
- Create `[tgcalls] tgcalls/v2/MtProtoDtlsTransport.cpp`
- Rename `[tgcalls] tgcalls/v2/MtProtoIceTransportTest.cpp` → `tgcalls/v2/MtProtoDtlsTransportTest.cpp` (content replaced)
- Modify `submodules/TgVoipWebrtc/BUILD` (two source lists, one `cc_test`)
- Modify `[tgcalls] Package.swift` (exclude list)

**Interfaces:**
- Consumes: `tgcalls::EncryptedConnection` (`Type::Transport`, `prepareForSendingRawMessage(rtc::CopyOnWriteBuffer&, bool)`, `handleIncomingRawPacket(const char*, size_t)` returning `DecryptedRawPacket{main, additional}` with `.message` buffers); `cricket::PF_SRTP_BYPASS` from `p2p/base/dtls_transport_internal.h`.
- Produces: `tgcalls::MtProtoDtlsTransport(cricket::IceTransportInternal*, EncryptionKey)`; `tgcalls::MtProtoDtlsTransportFactory(EncryptionKey)` implementing `cricket::DtlsTransportFactory`.

- [ ] **Step 1: Add the new source to both Bazel source lists and rename the test target**

In `submodules/TgVoipWebrtc/BUILD`, in BOTH lists that contain `"tgcalls/tgcalls/v2/MtProtoIceTransport.cpp"` (the `objc_library` sources near line 238 and the `tgcalls_core` `cc_library` near line 457), add directly after that line:

```python
    "tgcalls/tgcalls/v2/MtProtoDtlsTransport.cpp",
```

(keep the `MtProtoIceTransport.cpp` line for now; Task 4 removes it). Then change the test target:

```python
cc_test(
    name = "mtproto_dtls_transport_test",
    srcs = ["tgcalls/tgcalls/v2/MtProtoDtlsTransportTest.cpp"],
```

(the rest of that `cc_test` block is unchanged).

- [ ] **Step 2: Rename the test file and exclude it from SwiftPM**

```bash
cd /Users/isaac/build/telegram/telegram-ios/submodules/TgVoipWebrtc/tgcalls
git mv tgcalls/v2/MtProtoIceTransportTest.cpp tgcalls/v2/MtProtoDtlsTransportTest.cpp
grep -n "MtProtoIceTransportTest\|MtProtoDtlsTransportTest" Package.swift
```

If the grep prints a `MtProtoIceTransportTest.cpp` entry, rename it to `MtProtoDtlsTransportTest.cpp`. If it prints nothing, add `"tgcalls/v2/MtProtoDtlsTransportTest.cpp",` as a new entry in the `exclude: [` list (the first element is `"LICENSE",`), so SwiftPM never compiles its `main()`.

- [ ] **Step 3: Write the failing test file**

Replace the entire content of `tgcalls/v2/MtProtoDtlsTransportTest.cpp` with:

```cpp
#include "v2/MtProtoDtlsTransport.h"

#include "EncryptedConnection.h"

#include "api/crypto/crypto_options.h"
#include "media/sctp/dcsctp_transport.h"
#include "pc/rtp_transport.h"
#include "rtc_base/logging.h"
#include "rtc_base/rtc_certificate.h"
#include "rtc_base/ssl_identity.h"
#include "rtc_base/thread.h"
#include "system_wrappers/include/clock.h"

#include <array>
#include <cerrno>
#include <cstdio>
#include <memory>
#include <string>
#include <vector>

namespace {

int g_failures = 0;

#define CHECK_TRUE(cond)                                                  \
    do {                                                                  \
        if (!(cond)) {                                                    \
            std::printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);   \
            g_failures++;                                                 \
        }                                                                 \
    } while (0)

// Non-zero material, shared by both ends. EncryptedConnection seeds its keys from
// `key + 88 + (isOutgoing ? 0 : 8)` on one side and the mirror offset on the other,
// so a pair built from the SAME direction only interoperates when the key is all
// zeroes - which is exactly what an all-zero fixture would hide.
std::shared_ptr<std::array<uint8_t, 256>> makeSharedKeyMaterial() {
    auto key = std::make_shared<std::array<uint8_t, 256>>();
    for (size_t i = 0; i < key->size(); i++) {
        (*key)[i] = (uint8_t)(i * 7 + 13);
    }
    return key;
}

tgcalls::EncryptionKey outgoingKey(std::shared_ptr<std::array<uint8_t, 256>> key) {
    return tgcalls::EncryptionKey(key, true);
}

tgcalls::EncryptionKey incomingKey(std::shared_ptr<std::array<uint8_t, 256>> key) {
    return tgcalls::EncryptionKey(key, false);
}

// A local stand-in for P2PTransportChannel. webrtc's cricket::FakeIceTransport
// is not declared in third-party/webrtc/BUILD, so bazel's strict header check
// rejects it; this stubs the interface directly.
class FakeIceTransport : public cricket::IceTransportInternal {
public:
    FakeIceTransport() : _transportName("fake") {
    }

    void setWritable(bool writable) {
        _writable = writable;
        SignalWritableState(this);
    }
    void fireReadyToSend() { SignalReadyToSend(this); }
    // What P2PTransportChannel::GetError() would report: its error_ is only
    // written on a failed send and never cleared, so a stale value is realistic.
    void setError(int error) { _error = error; }
    void deliverPacket(const char *data, size_t size) {
        SignalReadPacket(this, data, size, 0, 0);
    }
    std::string lastSentPacket() const { return _lastSentPacket; }
    int sentPacketCount() const { return _sentPacketCount; }

    // rtc::PacketTransportInternal
    const std::string &transport_name() const override { return _transportName; }
    bool writable() const override { return _writable; }
    bool receiving() const override { return _receiving; }
    int SendPacket(const char *data, size_t len, const rtc::PacketOptions &, int) override {
        _lastSentPacket.assign(data, len);
        _sentPacketCount++;
        return (int)len;
    }
    int SetOption(rtc::Socket::Option, int) override { return 0; }
    bool GetOption(rtc::Socket::Option, int *) override { return false; }
    int GetError() override { return _error; }
    absl::optional<rtc::NetworkRoute> network_route() const override { return absl::nullopt; }

    // cricket::IceTransportInternal
    cricket::IceTransportState GetState() const override { return cricket::IceTransportState::STATE_INIT; }
    webrtc::IceTransportState GetIceTransportState() const override { return webrtc::IceTransportState::kNew; }
    int component() const override { return 1; }
    cricket::IceRole GetIceRole() const override { return cricket::ICEROLE_CONTROLLING; }
    void SetIceRole(cricket::IceRole) override {}
    void SetIceTiebreaker(uint64_t) override {}
    void SetIceParameters(const cricket::IceParameters &) override {}
    void SetRemoteIceParameters(const cricket::IceParameters &) override {}
    void SetRemoteIceMode(cricket::IceMode) override {}
    void SetIceConfig(const cricket::IceConfig &) override {}
    void MaybeStartGathering() override {}
    void AddRemoteCandidate(const cricket::Candidate &) override {}
    void RemoveRemoteCandidate(const cricket::Candidate &) override {}
    void RemoveAllRemoteCandidates() override {}
    cricket::IceGatheringState gathering_state() const override { return cricket::kIceGatheringNew; }
    bool GetStats(cricket::IceTransportStats *) override { return false; }
    absl::optional<int> GetRttEstimate() override { return absl::nullopt; }
    const cricket::Connection *selected_connection() const override { return nullptr; }
    absl::optional<const cricket::CandidatePair> GetSelectedCandidatePair() const override { return absl::nullopt; }

private:
    std::string _transportName;
    bool _writable = false;
    bool _receiving = false;
    int _sentPacketCount = 0;
    std::string _lastSentPacket;
    int _error = 0;
};

struct ReadPacketProbe : public sigslot::has_slots<> {
    int lastFlags = -1;
    int count = 0;
    std::string lastPayload;

    void onReadPacket(rtc::PacketTransportInternal *, const char *data, size_t size, const int64_t &, int flags) {
        lastFlags = flags;
        lastPayload.assign(data, size);
        count++;
    }
};

struct CapturingLogSink : public rtc::LogSink {
    std::vector<std::string> lines;
    void OnLogMessage(const std::string &message) override {
        lines.push_back(message);
    }
};

std::vector<uint8_t> makeRtpPacket(uint16_t seq) {
    // 12-byte RTP header (version 2, PT 111) + payload; >= 16 bytes so that
    // dcsctp's parser gets past its size check and would reach the checksum.
    return {0x80, 0x6f, (uint8_t)(seq >> 8), (uint8_t)seq, 0, 0, 0, 1, 0x11, 0x22, 0x33, 0x44, 'a', 'u', 'd', 'i', 'o'};
}

// A sender/receiver pair over one key, as a real call has.
struct Pair {
    std::shared_ptr<std::array<uint8_t, 256>> key = makeSharedKeyMaterial();
    FakeIceTransport senderIce;
    FakeIceTransport receiverIce;
    tgcalls::MtProtoDtlsTransport sender{&senderIce, outgoingKey(key)};
    tgcalls::MtProtoDtlsTransport receiver{&receiverIce, incomingKey(key)};

    // Encrypts on the sender, delivers the wire bytes to the receiver's ICE.
    void send(const std::string &payload, int flags) {
        rtc::PacketOptions options;
        sender.SendPacket(payload.data(), payload.size(), options, flags);
        const std::string onTheWire = senderIce.lastSentPacket();
        receiverIce.deliverPacket(onTheWire.data(), onTheWire.size());
    }
};

// ---------------------------------------------------------------------------
// DTLS-slot contract: the controller and the stats wrapper must see a
// transport that becomes connected without any handshake.
// ---------------------------------------------------------------------------

void TestStateBecomesConnectedWhenIceWritable() {
    FakeIceTransport ice;
    tgcalls::MtProtoDtlsTransport transport(&ice, outgoingKey(makeSharedKeyMaterial()));

    std::vector<webrtc::DtlsTransportState> published;
    transport.SubscribeDtlsTransportState([&published](cricket::DtlsTransportInternal *, webrtc::DtlsTransportState state) {
        published.push_back(state);
    });

    CHECK_TRUE(transport.dtls_state() == webrtc::DtlsTransportState::kNew);
    CHECK_TRUE(!transport.writable());

    ice.setWritable(true);
    CHECK_TRUE(transport.writable());
    CHECK_TRUE(transport.dtls_state() == webrtc::DtlsTransportState::kConnected);
    CHECK_TRUE(published.size() == 1);
    CHECK_TRUE(!published.empty() && published[0] == webrtc::DtlsTransportState::kConnected);

    // Losing ICE writability is an ICE matter; the DTLS state stays connected
    // (stock DTLS behaves the same: writable() drops, dtls_state() does not).
    ice.setWritable(false);
    CHECK_TRUE(!transport.writable());
    CHECK_TRUE(transport.dtls_state() == webrtc::DtlsTransportState::kConnected);
    CHECK_TRUE(published.size() == 1);
}

void TestNegotiationSurfaceRoundTrips() {
    FakeIceTransport ice;
    tgcalls::MtProtoDtlsTransport transport(&ice, outgoingKey(makeSharedKeyMaterial()));

    CHECK_TRUE(transport.IsDtlsActive());
    CHECK_TRUE(transport.ice_transport() == &ice);
    CHECK_TRUE(transport.component() == 1);

    auto certificate = rtc::RTCCertificate::Create(rtc::SSLIdentity::Create("test", rtc::KT_DEFAULT));
    CHECK_TRUE(transport.SetLocalCertificate(certificate));
    CHECK_TRUE(transport.GetLocalCertificate() == certificate);

    rtc::SSLRole role;
    CHECK_TRUE(!transport.GetDtlsRole(&role));
    const uint8_t digest[32] = {1, 2, 3};
    CHECK_TRUE(transport.SetRemoteParameters("sha-256", digest, sizeof(digest), rtc::SSL_SERVER).ok());
    CHECK_TRUE(transport.GetDtlsRole(&role));
    CHECK_TRUE(role == rtc::SSL_SERVER);

    int value = 0;
    CHECK_TRUE(!transport.GetSrtpCryptoSuite(&value));
    CHECK_TRUE(!transport.GetSslCipherSuite(&value));
    CHECK_TRUE(!transport.GetSslVersionBytes(&value));
    CHECK_TRUE(transport.GetSslPeerSignatureAlgorithm() == 0);
    CHECK_TRUE(transport.GetRemoteSSLCertChain() == nullptr);
    uint8_t material[16];
    CHECK_TRUE(!transport.ExportKeyingMaterial("label", nullptr, 0, false, material, sizeof(material)));
}

void TestFactoryCreatesTransportOverGivenIce() {
    FakeIceTransport ice;
    tgcalls::MtProtoDtlsTransportFactory factory(outgoingKey(makeSharedKeyMaterial()));
    auto transport = factory.CreateDtlsTransport(&ice, webrtc::CryptoOptions(), rtc::SSL_PROTOCOL_DTLS_12);
    CHECK_TRUE(transport != nullptr);
    CHECK_TRUE(transport && transport->ice_transport() == &ice);
}

// ---------------------------------------------------------------------------
// Framing: `flags` is ground truth in both directions, as in 13.0.0.
// ---------------------------------------------------------------------------

void TestSendPacketIsEncrypted() {
    FakeIceTransport ice;
    tgcalls::MtProtoDtlsTransport transport(&ice, outgoingKey(makeSharedKeyMaterial()));
    const std::string payload = "PLAINTEXTPAYLOAD";
    rtc::PacketOptions options;
    transport.SendPacket(payload.data(), payload.size(), options, cricket::PF_SRTP_BYPASS);
    CHECK_TRUE(ice.sentPacketCount() == 1);
    CHECK_TRUE(ice.lastSentPacket().find(payload) == std::string::npos);
}

// PacketTransportInternal contract: report the CALLER's byte count.
// RtpTransport::SendPacket treats any other value as a failed send.
void TestSendPacketReturnsPlaintextLength() {
    FakeIceTransport ice;
    tgcalls::MtProtoDtlsTransport transport(&ice, outgoingKey(makeSharedKeyMaterial()));
    const std::string payload = "PLAINTEXTPAYLOAD";
    rtc::PacketOptions options;
    const int ret = transport.SendPacket(payload.data(), payload.size(), options, cricket::PF_SRTP_BYPASS);
    CHECK_TRUE(ret == (int)payload.size());
}

void TestReadPacketFlagsFollowFraming() {
    Pair pair;
    ReadPacketProbe probe;
    pair.receiver.SignalReadPacket.connect(&probe, &ReadPacketProbe::onReadPacket);

    // RTP path: PF_SRTP_BYPASS in, PF_SRTP_BYPASS out, payload intact.
    const std::string rtp = "RTPPAYLOAD";
    pair.send(rtp, cricket::PF_SRTP_BYPASS);
    CHECK_TRUE(probe.count == 1);
    CHECK_TRUE(probe.lastPayload == rtp);
    CHECK_TRUE(probe.lastFlags == cricket::PF_SRTP_BYPASS);

    // SCTP path: 0 in, 0 out, the magic prefix added and stripped on the way.
    const std::string sctp = std::string("\x13\x88\x13\x88\x01\x02\x03\x04\x00\x00\x00\x00", 12) + "CHUNK";
    pair.send(sctp, 0);
    CHECK_TRUE(probe.count == 2);
    CHECK_TRUE(probe.lastPayload == sctp);
    CHECK_TRUE(probe.lastFlags == 0);
}

// The wire carries the 13.0.0 framing: an SCTP frame is prefixed 0xdcdcdcdc
// before encryption, an RTP frame is not. Decrypt on the receiver's connection
// and inspect the plaintext.
void TestWireFramingMatches13() {
    Pair pair;
    rtc::PacketOptions options;

    const std::string sctp = "SCTPBYTES";
    pair.sender.SendPacket(sctp.data(), sctp.size(), options, 0);
    tgcalls::EncryptedConnection decryptor(tgcalls::EncryptedConnection::Type::Transport, incomingKey(pair.key), [](int, int) {});
    const std::string sctpWire = pair.senderIce.lastSentPacket();
    const auto sctpPlain = decryptor.handleIncomingRawPacket(sctpWire.data(), sctpWire.size());
    CHECK_TRUE(sctpPlain.has_value());
    if (sctpPlain) {
        const auto &m = sctpPlain->main.message;
        CHECK_TRUE(m.size() == 4 + sctp.size());
        uint32_t magic = 0;
        memcpy(&magic, m.data(), 4);
        CHECK_TRUE(magic == 0xdcdcdcdc);
    }

    const std::string rtp = "RTPBYTES";
    pair.sender.SendPacket(rtp.data(), rtp.size(), options, cricket::PF_SRTP_BYPASS);
    const std::string rtpWire = pair.senderIce.lastSentPacket();
    const auto rtpPlain = decryptor.handleIncomingRawPacket(rtpWire.data(), rtpWire.size());
    CHECK_TRUE(rtpPlain.has_value());
    if (rtpPlain) {
        const auto &m = rtpPlain->main.message;
        CHECK_TRUE(m.size() == rtp.size());
        CHECK_TRUE(std::string((const char *)m.data(), m.size()) == rtp);
    }
}

// ---------------------------------------------------------------------------
// The production stack above the transport: webrtc::RtpTransport and
// webrtc::DcSctpTransport, exactly as JsepTransportController wires them.
// ---------------------------------------------------------------------------

struct ReadyToSendProbe {
    int downFlips = 0;
};

// P2PTransportChannel::error_ is written only on a failed send and never
// cleared. After one genuine ENOTCONN, a send that SUCCEEDS but returned the
// wrong length would make RtpTransport read that stale ENOTCONN and drop
// ready-to-send -> Call network DOWN -> pacer paused.
void TestStaleEnotconnMustNotDropReadyToSendAfterSuccessfulSend() {
    rtc::AutoThread thread;
    FakeIceTransport ice;
    tgcalls::MtProtoDtlsTransport transport(&ice, outgoingKey(makeSharedKeyMaterial()));

    webrtc::RtpTransport rtpTransport(/*rtcp_mux_enabled=*/true);
    rtpTransport.SetRtpPacketTransport(&transport);

    ReadyToSendProbe probe;
    rtpTransport.SubscribeReadyToSend(&probe, [&probe](bool ready) {
        if (!ready) {
            probe.downFlips++;
        }
    });

    ice.setWritable(true);
    ice.fireReadyToSend();
    CHECK_TRUE(rtpTransport.IsReadyToSend());

    ice.setError(ENOTCONN);

    const auto rtp = makeRtpPacket(1);
    rtc::CopyOnWriteBuffer packet(rtp.data(), rtp.size());
    rtc::PacketOptions options;
    // BaseChannel::SendPacket always passes PF_SRTP_BYPASS for RTP and RTCP.
    const bool sent = rtpTransport.SendRtpPacket(&packet, options, cricket::PF_SRTP_BYPASS);

    CHECK_TRUE(ice.sentPacketCount() == 1);
    CHECK_TRUE(sent);
    CHECK_TRUE(rtpTransport.IsReadyToSend());
    CHECK_TRUE(probe.downFlips == 0);

    rtpTransport.UnsubscribeReadyToSend(&probe);
}

// DcSctpTransport subscribes to the same SignalReadPacket as RtpTransport and
// skips only flags != 0. RTP must therefore surface with PF_SRTP_BYPASS, or
// every media packet is parsed (copy + CRC32c) and logged as an error.
void TestReceivedRtpMustNotReachSctp() {
    rtc::AutoThread thread;
    Pair pair;

    webrtc::RtpTransport rtpTransport(/*rtcp_mux_enabled=*/true);
    rtpTransport.SetRtpPacketTransport(&pair.receiver);
    webrtc::DcSctpTransport sctp(&thread, &pair.receiver, webrtc::Clock::GetRealTimeClock());
    CHECK_TRUE(sctp.Start(5000, 5000, 256 * 1024));

    ReadPacketProbe transportProbe;
    pair.receiver.SignalReadPacket.connect(&transportProbe, &ReadPacketProbe::onReadPacket);

    CapturingLogSink sink;
    rtc::LogMessage::AddLogToStream(&sink, rtc::LS_ERROR);

    const int kPackets = 50;
    for (int i = 0; i < kPackets; i++) {
        const auto rtp = makeRtpPacket((uint16_t)i);
        pair.send(std::string((const char *)rtp.data(), rtp.size()), cricket::PF_SRTP_BYPASS);
    }

    rtc::LogMessage::RemoveLogToStream(&sink);

    int parseFailures = 0;
    for (const auto &line : sink.lines) {
        if (line.find("PARSE_FAILED") != std::string::npos) {
            parseFailures++;
        }
    }
    CHECK_TRUE(transportProbe.count == kPackets);
    CHECK_TRUE(transportProbe.lastFlags == cricket::PF_SRTP_BYPASS);
    CHECK_TRUE(parseFailures == 0);
}

} // namespace

int main() {
    TestStateBecomesConnectedWhenIceWritable();
    TestNegotiationSurfaceRoundTrips();
    TestFactoryCreatesTransportOverGivenIce();

    TestSendPacketIsEncrypted();
    TestSendPacketReturnsPlaintextLength();
    TestReadPacketFlagsFollowFraming();
    TestWireFramingMatches13();

    TestStaleEnotconnMustNotDropReadyToSendAfterSuccessfulSend();
    TestReceivedRtpMustNotReachSctp();

    if (g_failures != 0) {
        std::printf("%d failure(s)\n", g_failures);
        return 1;
    }
    std::printf("ok\n");
    return 0;
}
```

- [ ] **Step 4: Run the test to verify it fails to build**

```bash
cd /Users/isaac/build/telegram/telegram-ios
./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TgVoipWebrtc:mtproto_dtls_transport_test --test_output=all 2>&1 | grep -E "error:|FAILED|PASSED" | head
```

Expected: a compile error `'v2/MtProtoDtlsTransport.h' file not found` (or the missing `MtProtoDtlsTransport.cpp` source).

- [ ] **Step 5: Write the header**

Create `tgcalls/v2/MtProtoDtlsTransport.h`:

```cpp
#ifndef TGCALLS_MTPROTO_DTLS_TRANSPORT_H
#define TGCALLS_MTPROTO_DTLS_TRANSPORT_H

#include <memory>
#include <string>

#include "Instance.h"
#include "api/dtls_transport_interface.h"
#include "p2p/base/dtls_transport_factory.h"
#include "p2p/base/dtls_transport_internal.h"
#include "p2p/base/ice_transport_internal.h"
#include "rtc_base/buffer.h"
#include "rtc_base/copy_on_write_buffer.h"
#include "rtc_base/rtc_certificate.h"

namespace tgcalls {

class EncryptedConnection;

// mtproto in the DTLS slot. Injected through
// PeerConnectionDependencies::dtls_transport_factory (a tgcalls seam in the
// vendored webrtc) together with Options::external_transport_security, which
// makes JsepTransportController build a plain RtpTransport above us while
// DTLS stays enabled for SDP: certificates, fingerprints and the SCTP factory
// are stock. We never handshake - the shared secret exists before the call
// starts - and report kConnected the first time ICE becomes writable.
//
// Framing is byte-identical to 13.0.0's MtProtoPacketTransport, and `flags`
// is ground truth in both directions: BaseChannel sends RTP/RTCP with
// PF_SRTP_BYPASS (framed bare) and DcSctpTransport sends SCTP with 0 (framed
// with the 0xdcdcdcdc prefix); on receive the prefix becomes flags 0 and its
// absence PF_SRTP_BYPASS, so DcSctpTransport (which skips flags != 0) never
// parses media and RtpTransport (which ignores flags) demuxes it.
//
// Design record: telegram-ios
// docs/superpowers/specs/2026-09-16-tgcalls-mtproto-dtls-slot-design.md.
class MtProtoDtlsTransport : public cricket::DtlsTransportInternal {
public:
    MtProtoDtlsTransport(cricket::IceTransportInternal *ice, EncryptionKey encryptionKey);
    ~MtProtoDtlsTransport() override;

    // rtc::PacketTransportInternal
    const std::string &transport_name() const override;
    bool writable() const override;
    bool receiving() const override;
    int SendPacket(const char *data, size_t len, const rtc::PacketOptions &options, int flags) override;
    int SetOption(rtc::Socket::Option opt, int value) override;
    bool GetOption(rtc::Socket::Option opt, int *value) override;
    int GetError() override;
    absl::optional<rtc::NetworkRoute> network_route() const override;

    // cricket::DtlsTransportInternal
    webrtc::DtlsTransportState dtls_state() const override;
    int component() const override;
    bool IsDtlsActive() const override;
    bool GetDtlsRole(rtc::SSLRole *role) const override;
    bool SetDtlsRole(rtc::SSLRole role) override;
    bool GetSslVersionBytes(int *version) const override;
    bool GetSrtpCryptoSuite(int *cipher) override;
    bool GetSslCipherSuite(int *cipher) override;
    uint16_t GetSslPeerSignatureAlgorithm() const override;
    rtc::scoped_refptr<rtc::RTCCertificate> GetLocalCertificate() const override;
    bool SetLocalCertificate(const rtc::scoped_refptr<rtc::RTCCertificate> &certificate) override;
    std::unique_ptr<rtc::SSLCertChain> GetRemoteSSLCertChain() const override;
    bool ExportKeyingMaterial(absl::string_view label, const uint8_t *context, size_t context_len, bool use_context, uint8_t *result, size_t result_len) override;
    bool SetRemoteFingerprint(absl::string_view digest_alg, const uint8_t *digest, size_t digest_len) override;
    webrtc::RTCError SetRemoteParameters(absl::string_view digest_alg, const uint8_t *digest, size_t digest_len, absl::optional<rtc::SSLRole> role) override;
    cricket::IceTransportInternal *ice_transport() override;

private:
    // The seven rtc::PacketTransportInternal signals of the ICE transport,
    // re-emitted with `this`: the controller keys transports by pointer.
    void onIceWritableState(rtc::PacketTransportInternal *transport);
    void onIceReceivingState(rtc::PacketTransportInternal *transport);
    void onIceReadyToSend(rtc::PacketTransportInternal *transport);
    void onIceReadPacket(rtc::PacketTransportInternal *transport, const char *data, size_t size, const int64_t &timestamp, int flags);
    void onIceSentPacket(rtc::PacketTransportInternal *transport, const rtc::SentPacket &packet);
    void onIceNetworkRouteChanged(absl::optional<rtc::NetworkRoute> route);
    void onIceClosed(rtc::PacketTransportInternal *transport);

    void emitDecryptedMessage(rtc::CopyOnWriteBuffer const &message, int64_t timestamp);
    void setDtlsState(webrtc::DtlsTransportState state);

    cricket::IceTransportInternal *_ice = nullptr;
    std::unique_ptr<EncryptedConnection> _transportEncryption;
    webrtc::DtlsTransportState _dtlsState = webrtc::DtlsTransportState::kNew;
    absl::optional<rtc::SSLRole> _dtlsRole;
    rtc::scoped_refptr<rtc::RTCCertificate> _localCertificate;
    std::string _remoteFingerprintAlgorithm;
    rtc::Buffer _remoteFingerprintValue;
};

// Installed on PeerConnectionDependencies::dtls_transport_factory by
// InstanceV2ReferenceImpl and CallCoreHost, always together with
// Options::external_transport_security, from the one network_use_mtproto
// decision.
class MtProtoDtlsTransportFactory : public cricket::DtlsTransportFactory {
public:
    explicit MtProtoDtlsTransportFactory(EncryptionKey encryptionKey);

    std::unique_ptr<cricket::DtlsTransportInternal> CreateDtlsTransport(
        cricket::IceTransportInternal *ice,
        const webrtc::CryptoOptions &crypto_options,
        rtc::SSLProtocolVersion max_version) override;

private:
    EncryptionKey _encryptionKey;
};

} // namespace tgcalls

#endif
```

- [ ] **Step 6: Write the implementation**

Create `tgcalls/v2/MtProtoDtlsTransport.cpp`:

```cpp
#include "v2/MtProtoDtlsTransport.h"

#include "EncryptedConnection.h"

#include <cstring>

namespace {

// Matches 13.0.0's MtProtoPacketTransport (NativeNetworkingImpl.cpp).
constexpr uint32_t kSctpMagic = 0xdcdcdcdc;

} // namespace

namespace tgcalls {

MtProtoDtlsTransport::MtProtoDtlsTransport(cricket::IceTransportInternal *ice, EncryptionKey encryptionKey) :
_ice(ice) {
    _transportEncryption = std::make_unique<EncryptedConnection>(
        EncryptedConnection::Type::Transport,
        encryptionKey,
        [](int delayMs, int cause) {
        }
    );

    _ice->SignalWritableState.connect(this, &MtProtoDtlsTransport::onIceWritableState);
    _ice->SignalReceivingState.connect(this, &MtProtoDtlsTransport::onIceReceivingState);
    _ice->SignalReadyToSend.connect(this, &MtProtoDtlsTransport::onIceReadyToSend);
    _ice->SignalReadPacket.connect(this, &MtProtoDtlsTransport::onIceReadPacket);
    _ice->SignalSentPacket.connect(this, &MtProtoDtlsTransport::onIceSentPacket);
    _ice->SignalNetworkRouteChanged.connect(this, &MtProtoDtlsTransport::onIceNetworkRouteChanged);
    _ice->SignalClosed.connect(this, &MtProtoDtlsTransport::onIceClosed);
}

MtProtoDtlsTransport::~MtProtoDtlsTransport() {
    _ice->SignalWritableState.disconnect(this);
    _ice->SignalReceivingState.disconnect(this);
    _ice->SignalReadyToSend.disconnect(this);
    _ice->SignalReadPacket.disconnect(this);
    _ice->SignalSentPacket.disconnect(this);
    _ice->SignalNetworkRouteChanged.disconnect(this);
    _ice->SignalClosed.disconnect(this);
}

// ---- rtc::PacketTransportInternal ----

const std::string &MtProtoDtlsTransport::transport_name() const {
    return _ice->transport_name();
}

bool MtProtoDtlsTransport::writable() const {
    return _ice->writable();
}

bool MtProtoDtlsTransport::receiving() const {
    return _ice->receiving();
}

int MtProtoDtlsTransport::SendPacket(const char *data, size_t len, const rtc::PacketOptions &options, int flags) {
    // `flags` is ground truth (13.0.0 semantics): BaseChannel sends RTP and RTCP
    // with PF_SRTP_BYPASS, DcSctpTransport sends SCTP with 0.
    rtc::CopyOnWriteBuffer buffer;
    if (flags == 0) {
        uint32_t magic = kSctpMagic;
        buffer.AppendData((const unsigned char *)&magic, 4);
    }
    buffer.AppendData((const unsigned char *)data, len);

    const auto encryptedPacket = _transportEncryption->prepareForSendingRawMessage(buffer, false);
    if (!encryptedPacket) {
        return -1;
    }

    // Flags never reach the ICE channel: P2PTransportChannel::SendPacket rejects
    // any non-zero value with EINVAL.
    const int sent = _ice->SendPacket((const char *)encryptedPacket->bytes.data(), encryptedPacket->bytes.size(), options, 0);
    if (sent < 0) {
        return sent;
    }

    // PacketTransportInternal contract: report the CALLER's byte count, never the
    // ciphertext's. RtpTransport::SendPacket treats any other value as a failed
    // send and then consults the ICE channel's last error, which
    // P2PTransportChannel never clears; a stale ENOTCONN would then drop
    // ready-to-send and pause the pacer for a call whose packets are going out.
    return (int)len;
}

int MtProtoDtlsTransport::SetOption(rtc::Socket::Option opt, int value) {
    return _ice->SetOption(opt, value);
}

bool MtProtoDtlsTransport::GetOption(rtc::Socket::Option opt, int *value) {
    return _ice->GetOption(opt, value);
}

int MtProtoDtlsTransport::GetError() {
    return _ice->GetError();
}

absl::optional<rtc::NetworkRoute> MtProtoDtlsTransport::network_route() const {
    return _ice->network_route();
}

// ---- cricket::DtlsTransportInternal ----

webrtc::DtlsTransportState MtProtoDtlsTransport::dtls_state() const {
    return _dtlsState;
}

int MtProtoDtlsTransport::component() const {
    return _ice->component();
}

bool MtProtoDtlsTransport::IsDtlsActive() const {
    return true;
}

bool MtProtoDtlsTransport::GetDtlsRole(rtc::SSLRole *role) const {
    if (!_dtlsRole) {
        return false;
    }
    *role = *_dtlsRole;
    return true;
}

bool MtProtoDtlsTransport::SetDtlsRole(rtc::SSLRole role) {
    _dtlsRole = role;
    return true;
}

bool MtProtoDtlsTransport::GetSslVersionBytes(int *version) const {
    return false;
}

bool MtProtoDtlsTransport::GetSrtpCryptoSuite(int *cipher) {
    // No SRTP: the plain RtpTransport above us never asks for keys, and
    // returning false keeps the stats wrapper's fields absent rather than wrong.
    return false;
}

bool MtProtoDtlsTransport::GetSslCipherSuite(int *cipher) {
    return false;
}

uint16_t MtProtoDtlsTransport::GetSslPeerSignatureAlgorithm() const {
    return 0;
}

rtc::scoped_refptr<rtc::RTCCertificate> MtProtoDtlsTransport::GetLocalCertificate() const {
    return _localCertificate;
}

bool MtProtoDtlsTransport::SetLocalCertificate(const rtc::scoped_refptr<rtc::RTCCertificate> &certificate) {
    // Stored only so the controller's fingerprint lands in the SDP; it is never
    // used for a handshake.
    _localCertificate = certificate;
    return true;
}

std::unique_ptr<rtc::SSLCertChain> MtProtoDtlsTransport::GetRemoteSSLCertChain() const {
    return nullptr;
}

bool MtProtoDtlsTransport::ExportKeyingMaterial(absl::string_view label, const uint8_t *context, size_t context_len, bool use_context, uint8_t *result, size_t result_len) {
    return false;
}

bool MtProtoDtlsTransport::SetRemoteFingerprint(absl::string_view digest_alg, const uint8_t *digest, size_t digest_len) {
    return SetRemoteParameters(digest_alg, digest, digest_len, absl::nullopt).ok();
}

webrtc::RTCError MtProtoDtlsTransport::SetRemoteParameters(absl::string_view digest_alg, const uint8_t *digest, size_t digest_len, absl::optional<rtc::SSLRole> role) {
    // Accepted and stored, never verified: mtproto's shared key is the
    // authentication. The role is what JsepTransport negotiated from a=setup.
    _remoteFingerprintAlgorithm = std::string(digest_alg);
    _remoteFingerprintValue.SetData(digest, digest_len);
    if (role) {
        _dtlsRole = role;
    }
    return webrtc::RTCError::OK();
}

cricket::IceTransportInternal *MtProtoDtlsTransport::ice_transport() {
    return _ice;
}

// ---- ICE signal bridges ----

void MtProtoDtlsTransport::onIceWritableState(rtc::PacketTransportInternal *) {
    if (_ice->writable() && _dtlsState == webrtc::DtlsTransportState::kNew) {
        // No handshake: the shared key existed before the call started.
        setDtlsState(webrtc::DtlsTransportState::kConnected);
    }
    SignalWritableState(this);
}

void MtProtoDtlsTransport::onIceReceivingState(rtc::PacketTransportInternal *) {
    SignalReceivingState(this);
}

void MtProtoDtlsTransport::onIceReadyToSend(rtc::PacketTransportInternal *) {
    if (writable()) {
        SignalReadyToSend(this);
    }
}

void MtProtoDtlsTransport::onIceReadPacket(rtc::PacketTransportInternal *, const char *data, size_t size, const int64_t &timestamp, int flags) {
    if (const auto packet = _transportEncryption->handleIncomingRawPacket(data, size)) {
        emitDecryptedMessage(packet.value().main.message, timestamp);
        for (const auto &additional : packet.value().additional) {
            emitDecryptedMessage(additional.message, timestamp);
        }
    }
    // Undecryptable: dropped silently, as EncryptedConnection always has.
}

void MtProtoDtlsTransport::emitDecryptedMessage(rtc::CopyOnWriteBuffer const &message, int64_t timestamp) {
    // The prefix IS the demux: SCTP surfaces with flags 0, which DcSctpTransport
    // accepts; everything else with PF_SRTP_BYPASS, which DcSctpTransport skips
    // and RtpTransport ignores. Active DTLS emits the same flag for SRTP.
    if (message.size() >= 4) {
        uint32_t header = 0;
        memcpy(&header, message.data(), 4);
        if (header == kSctpMagic) {
            SignalReadPacket(this, (const char *)(message.data() + 4), message.size() - 4, timestamp, 0);
            return;
        }
    }
    SignalReadPacket(this, (const char *)message.data(), message.size(), timestamp, cricket::PF_SRTP_BYPASS);
}

void MtProtoDtlsTransport::onIceSentPacket(rtc::PacketTransportInternal *, const rtc::SentPacket &packet) {
    SignalSentPacket(this, packet);
}

void MtProtoDtlsTransport::onIceNetworkRouteChanged(absl::optional<rtc::NetworkRoute> route) {
    SignalNetworkRouteChanged(route);
}

void MtProtoDtlsTransport::onIceClosed(rtc::PacketTransportInternal *) {
    SignalClosed(this);
}

void MtProtoDtlsTransport::setDtlsState(webrtc::DtlsTransportState state) {
    if (_dtlsState == state) {
        return;
    }
    _dtlsState = state;
    // Published so the aggregate PeerConnectionState and the webrtc::DtlsTransport
    // stats wrapper see a connected transport.
    SendDtlsState(this, state);
}

// ---- factory ----

MtProtoDtlsTransportFactory::MtProtoDtlsTransportFactory(EncryptionKey encryptionKey) :
_encryptionKey(std::move(encryptionKey)) {
}

std::unique_ptr<cricket::DtlsTransportInternal> MtProtoDtlsTransportFactory::CreateDtlsTransport(
    cricket::IceTransportInternal *ice,
    const webrtc::CryptoOptions &crypto_options,
    rtc::SSLProtocolVersion max_version
) {
    return std::make_unique<MtProtoDtlsTransport>(ice, _encryptionKey);
}

} // namespace tgcalls
```

- [ ] **Step 7: Run the test to verify it passes**

```bash
cd /Users/isaac/build/telegram/telegram-ios
./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TgVoipWebrtc:mtproto_dtls_transport_test --test_output=all 2>&1 | sed -n '/Test output/,/====$/p;/error:/p;/FAILED\|PASSED/p'
```

Expected: `ok` and `PASSED`. If `TestWireFramingMatches13` fails on `handleIncomingRawPacket`, the decryptor is not consuming the sender's counters in order; construct it before the first `SendPacket` in that test (it must see seq 1 then seq 2).

- [ ] **Step 8: Commit in the tgcalls submodule**

```bash
cd /Users/isaac/build/telegram/telegram-ios/submodules/TgVoipWebrtc/tgcalls
git add tgcalls/v2/MtProtoDtlsTransport.h tgcalls/v2/MtProtoDtlsTransport.cpp tgcalls/v2/MtProtoDtlsTransportTest.cpp Package.swift
git commit -m "v2: MtProtoDtlsTransport - mtproto in the DTLS slot, no handshake

A cricket::DtlsTransportInternal for PeerConnectionDependencies::
dtls_transport_factory (tgcalls seam in the vendored webrtc). It never
handshakes - the shared key exists before the call starts - and reports
kConnected the first time ICE is writable. Framing is byte-identical to
13.0.0's MtProtoPacketTransport with flags as ground truth in both directions
(PF_SRTP_BYPASS = RTP framed bare, 0 = SCTP with the 0xdcdcdcdc prefix), so
DcSctpTransport never parses media. SendPacket returns the caller's length.

The host test stacks a real webrtc::RtpTransport and webrtc::DcSctpTransport
over the transport: state/negotiation surface, framing both ways, wire parity,
stale-ENOTCONN ready-to-send, zero SCTP parse errors for received RTP.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

(The `BUILD` change lives in telegram-ios and is committed in Task 5.)

---

### Task 3: Install option + factory in the two PeerConnection engines

**Files:**
- Modify `[tgcalls] tgcalls/v2/InstanceV2ReferenceImpl.cpp` (include near line 61; factory options block near line 494; dependencies near line 774)
- Modify `[tgcalls] tgcalls/v2wasm/CallCoreHost.cpp` (include near line 26; factory options near line 604; dependencies near line 951)

**Interfaces:**
- Consumes: `webrtc::PeerConnectionFactoryInterface::Options::external_transport_security`, `webrtc::PeerConnectionDependencies::dtls_transport_factory` (Task 1); `tgcalls::MtProtoDtlsTransportFactory` (Task 2).

- [ ] **Step 1: `InstanceV2ReferenceImpl.cpp`**

(a) Replace `#include "v2/MtProtoIceTransport.h"` with `#include "v2/MtProtoDtlsTransport.h"`.

(b) Replace the block

```cpp
        _useMtProto = getCustomParameterBool(_customParameters, "network_use_mtproto");
        if (_useMtProto) {
            // Selects CreateUnencryptedRtpTransport - a plain RtpTransport, the
            // same class 13.0.0 uses - instead of DtlsSrtpTransport. NOT optional:
            // SrtpTransport hard-fails when SRTP is inactive (send returns false,
            // receive drops), so without this the call is either double-encrypted
            // or dead. Nothing ends up unencrypted: mtproto replaces DTLS-SRTP.
            // Must precede CreatePeerConnectionOrError, where DtlsEnabled() is read.
            webrtc::PeerConnectionFactoryInterface::Options factoryOptions;
            factoryOptions.disable_encryption = true;
            _peerConnectionFactory->SetOptions(factoryOptions);
        }
```

with

```cpp
        _useMtProto = getCustomParameterBool(_customParameters, "network_use_mtproto");
        if (_useMtProto) {
            // Half one of two that MUST travel together (the other is the
            // MtProtoDtlsTransportFactory on the dependencies below). Selects the
            // plain RtpTransport (no SRTP) while DTLS stays enabled for SDP, so
            // certificates, fingerprints, the SCTP factory and data-channel
            // negotiation are stock; the factory then puts mtproto in the DTLS
            // slot with no handshake. Must precede CreatePeerConnectionOrError.
            webrtc::PeerConnectionFactoryInterface::Options factoryOptions;
            factoryOptions.external_transport_security = true;
            _peerConnectionFactory->SetOptions(factoryOptions);
        }
```

(c) Replace

```cpp
        if (_useMtProto) {
            peerConnectionDependencies.ice_transport_factory = std::make_unique<MtProtoIceTransportFactory>(_encryptionKey);
        }
```

with

```cpp
        if (_useMtProto) {
            // Half two: see the factory option above.
            peerConnectionDependencies.dtls_transport_factory = std::make_unique<MtProtoDtlsTransportFactory>(_encryptionKey);
        }
```

- [ ] **Step 2: `CallCoreHost.cpp`**

(a) Replace `#include "v2/MtProtoIceTransport.h"` with `#include "v2/MtProtoDtlsTransport.h"`.

(b) Replace

```cpp
    if (getCustomParameterBool(_parsedCustomParameters, "network_use_mtproto")) {
        // As in InstanceV2ReferenceImpl: selects a plain RtpTransport, matching
        // 13.0.0. SrtpTransport hard-fails when SRTP is inactive, so this is not
        // optional. Must precede CreatePeerConnectionOrError.
        webrtc::PeerConnectionFactoryInterface::Options factoryOptions;
        factoryOptions.disable_encryption = true;
        _peerConnectionFactory->SetOptions(factoryOptions);
    }
```

with

```cpp
    if (getCustomParameterBool(_parsedCustomParameters, "network_use_mtproto")) {
        // As in InstanceV2ReferenceImpl: half one of two that travel together
        // (the MtProtoDtlsTransportFactory in executePcCreate is the other).
        // Plain RtpTransport, DTLS kept enabled for SDP, mtproto in the DTLS
        // slot. Must precede CreatePeerConnectionOrError.
        webrtc::PeerConnectionFactoryInterface::Options factoryOptions;
        factoryOptions.external_transport_security = true;
        _peerConnectionFactory->SetOptions(factoryOptions);
    }
```

(c) Replace

```cpp
    if (getCustomParameterBool(_parsedCustomParameters, "network_use_mtproto")) {
        // Host-side by necessity, not preference: EncryptionKey is a secret and
        // must not cross into the wasm module, so the core cannot own this.
        peerConnectionDependencies.ice_transport_factory = std::make_unique<MtProtoIceTransportFactory>(_encryptionKey);
    }
```

with

```cpp
    if (getCustomParameterBool(_parsedCustomParameters, "network_use_mtproto")) {
        // Host-side by necessity, not preference: EncryptionKey is a secret and
        // must not cross into the wasm module, so the core cannot own this.
        // Half two of the mtproto pair; see start().
        peerConnectionDependencies.dtls_transport_factory = std::make_unique<MtProtoDtlsTransportFactory>(_encryptionKey);
    }
```

- [ ] **Step 3: Build the CLI and run the loopback matrix**

```bash
cd /Users/isaac/build/telegram/telegram-ios
./build-input/bazel-9.2.0-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli 2>&1 | grep -E "error:|Build completed"
S=/tmp/mtproto-dtls-slot; mkdir -p $S
CLI=bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
report() { f=$1; echo "$f: exit=$2 rejectedDC=$(grep -c 'Rejected data channel transport' $S/$f.log) SLD=$(grep -c 'Calling SetLocalDescription\|CallCoreHost: SetLocalDescription' $S/$f.log) openAck=$(grep -c 'OPEN_ACK' $S/$f.log) parseFailed=$(grep -c PARSE_FAILED $S/$f.log) dtlsSrtp=$(grep -c 'Creating DtlsSrtpTransport' $S/$f.log) dtlsHandshake=$(grep -ci 'DtlsTransport\[.*\]: DTLS handshake\|dtls_transport.cc.*handshake' $S/$f.log) unencrypted=$(grep -c 'Creating UnencryptedRtpTransport' $S/$f.log) lines=$(wc -l < $S/$f.log)"; }
for V in 11.0.0 18.0.0 19.0.0; do
  $CLI --mode p2p --duration 6 --version $V --custom-params '{"network_use_mtproto":true}' --custom-params2 '{"network_use_mtproto":true}' --log-file $S/mtproto-$V.log --quiet > /dev/null 2>&1; report mtproto-$V $?
  $CLI --mode p2p --duration 6 --version $V --log-file $S/plain-$V.log --quiet > /dev/null 2>&1; report plain-$V $?
done
```

Expected for every `mtproto-*`: `exit=0 rejectedDC=0 SLD=4 openAck=1 parseFailed=0 dtlsSrtp=0 dtlsHandshake=0 unencrypted=2`, lines roughly 700–900. Expected for every `plain-*`: `exit=0 rejectedDC=0 SLD=4 openAck=1 parseFailed=0 unencrypted=0` and `dtlsSrtp=2`. Any `Rejected data channel transport` or `PARSE_FAILED` count above zero, or `SLD` above 4, is a failure: stop and diagnose before committing.

- [ ] **Step 4: Commit in the tgcalls submodule**

```bash
cd /Users/isaac/build/telegram/telegram-ios/submodules/TgVoipWebrtc/tgcalls
git add tgcalls/v2/InstanceV2ReferenceImpl.cpp tgcalls/v2wasm/CallCoreHost.cpp
git commit -m "v2: install mtproto through the DTLS-slot factory in 11.0.0 and 18/19

network_use_mtproto now sets Options::external_transport_security and
PeerConnectionDependencies::dtls_transport_factory = MtProtoDtlsTransportFactory,
both from the one decision, instead of disable_encryption plus the ICE-level
decorator. Verified with tgcalls_cli loopback on 11.0.0, 18.0.0 and 19.0.0 with
mtproto on both ends: 4 SetLocalDescription, data channel OPEN_ACK, zero
rejected data sections, zero SCTP parse errors, zero DTLS handshake lines,
UnencryptedRtpTransport on both ends; plain calls unchanged.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Group-call SSRC discovery through `OnUnDemuxableRtpPacket`; delete the decorator

**Files:**
- Modify `[tgcalls] tgcalls/group/GroupInstanceReferenceImpl.cpp` (includes near lines 50–51; `GRPeerConnectionObserver` near line 82; the tap-install block starting at `// Transport-level audio SSRC discovery.` near line 828)
- Delete `[tgcalls] tgcalls/v2/MtProtoIceTransport.h`, `tgcalls/v2/MtProtoIceTransport.cpp`
- Modify `submodules/TgVoipWebrtc/BUILD` (remove two `MtProtoIceTransport.cpp` lines)

**Interfaces:**
- Consumes: `webrtc::PeerConnectionObserver::OnUnDemuxableRtpPacket(const webrtc::RtpPacketReceived&)` (Task 1); `webrtc::RtpPacketReceived::PayloadType()`, `::Ssrc()`; existing `AudioSsrcTap::shouldReport(uint32_t)`, `GRUserIdRegistry::isKnown(uint32_t)`, `handleDiscoveredAudioSsrc(uint32_t)`.

- [ ] **Step 1: Includes**

Replace `#include "v2/MtProtoIceTransport.h"` with `#include "modules/rtp_rtcp/source/rtp_packet_received.h"`. Delete the line `#include "media/base/rtp_utils.h"` (its only use was the tap's `InferRtpPacketType`; verify with `grep -n InferRtpPacketType tgcalls/group/GroupInstanceReferenceImpl.cpp` after Step 3, which must print nothing).

- [ ] **Step 2: Extend the observer adapter**

In `class GRPeerConnectionObserver`, after
`std::function<void(webrtc::scoped_refptr<webrtc::DataChannelInterface>)> onDataChannel;` add:

```cpp
    // Network thread, once per RTP packet the demuxer dropped. Keep it cheap.
    std::function<void(const webrtc::RtpPacketReceived &)> onUnDemuxableRtpPacket;
```

and after the `OnRemoveTrack(...) override {}` line add:

```cpp
    void OnUnDemuxableRtpPacket(const webrtc::RtpPacketReceived &packet) override {
        if (onUnDemuxableRtpPacket) onUnDemuxableRtpPacket(packet);
    }
```

- [ ] **Step 3: Replace the tap installation**

Replace everything from the comment line `// Transport-level audio SSRC discovery. This is the ONLY place a packet` through the closing `}` of the block that assigns `pcDeps.ice_transport_factory = std::make_unique<MtProtoIceTransportFactory>(` (the block ends with `});` for the lambda argument followed by `}` closing the scope opened after `_audioSsrcTap = std::make_shared<AudioSsrcTap>();`) with:

```cpp
        // Audio SSRC discovery for a participant who starts sending after the
        // call settled. Once two receiving audio m-lines in the BUNDLE group
        // advertise Opus 111 (sendrecv mid=0 plus one recvonly per remote SSRC),
        // SdpOfferAnswerHandler::UpdatePayloadTypeDemuxingState disables
        // payload-type demuxing and resets the unsignaled catch-all, so an
        // unknown SSRC - no MID extension (buildRemoteAnswer strips it), no SSRC
        // binding - is dropped by RtpDemuxer before any receive stream or frame
        // transformer exists. RtpTransport reports exactly those drops through
        // PeerConnectionObserver::OnUnDemuxableRtpPacket (a tgcalls seam in the
        // vendored webrtc), parsed and SRTP-unprotected, on the network thread.
        // Packets that still reach the mid=0 catch-all are demuxed, never arrive
        // here, and are covered by the GRAudioFrameTransformer as before.
        _audioSsrcTap = std::make_shared<AudioSsrcTap>();
        {
            auto tap = _audioSsrcTap;
            auto threads = _threads;
            auto userIds = _userIds;
            const bool hasE2e = (bool)_e2eEncryptDecrypt;
            const uint8_t opusPayloadType = kOpusPayloadType;
            _peerConnectionObserver->onUnDemuxableRtpPacket = [tap, weak, threads, userIds, hasE2e, opusPayloadType](const webrtc::RtpPacketReceived &packet) {
                // Payload types are pinned in group calls (mungeVideoCodecsInOffer),
                // so the audio stream is identifiable without parsing further.
                if (packet.PayloadType() != opusPayloadType) {
                    return;
                }
                const uint32_t ssrc = packet.Ssrc();
                if (ssrc == 0) {
                    return;
                }
                bool report = tap->shouldReport(ssrc);
                // Mirrors GRAudioFrameTransformer: while encryption is on and the
                // sender is still unknown, keep reporting so
                // handleDiscoveredAudioSsrc re-asks for the description (it de-dupes
                // on the in-flight request). A response that omits the SSRC would
                // otherwise leave that participant permanently undecryptable.
                if (!report && hasE2e && userIds && !userIds->isKnown(ssrc)) {
                    report = true;
                }
                if (!report) {
                    return;
                }
                threads->getMediaThread()->PostTask([weak, ssrc]() {
                    if (auto strong = weak.lock()) {
                        strong->handleDiscoveredAudioSsrc(ssrc);
                    }
                });
            };
        }
```

`weak` is the `std::weak_ptr` to the engine already captured by the neighbouring `onTrack` lambda in the same function; if the compiler reports it undeclared at this point, add `const auto weak = std::weak_ptr<GroupInstanceReferenceImplInternal>(shared_from_this());` directly above `_audioSsrcTap = ...` using the same class name the neighbouring lambda uses.

Update the `AudioSsrcTap` class comment's first line from `// De-duplication for the transport-level audio SSRC tap. Touched from the network` to `// De-duplication for the un-demuxable-packet audio SSRC tap. Touched from the network`.

- [ ] **Step 4: Delete the decorator and its build entries**

```bash
cd /Users/isaac/build/telegram/telegram-ios/submodules/TgVoipWebrtc/tgcalls
git rm -q tgcalls/v2/MtProtoIceTransport.h tgcalls/v2/MtProtoIceTransport.cpp
grep -rn "MtProtoIceTransport" tgcalls/ CLAUDE.md | grep -v "^CLAUDE.md" ; echo "(expect no source hits)"
```

In `submodules/TgVoipWebrtc/BUILD`, delete both lines `"tgcalls/tgcalls/v2/MtProtoIceTransport.cpp",`.

- [ ] **Step 5: Build and run the group check**

```bash
cd /Users/isaac/build/telegram/telegram-ios
./build-input/bazel-9.2.0-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli 2>&1 | grep -E "error:|Build completed"
CLI=bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
$CLI --mode group --participants 2 --reference-participants 1 --mute-participants 1 --unmute-after 8 --duration 20 2>&1 | grep -E "Late unmute heard|Errors|exit" ; echo "exit=$?"
$CLI --mode group --participants 1 --reference-participants 1 --mute-participants 0 --unmute-after 8 --duration 20 2>&1 | grep -E "Late unmute heard|Errors"
```

Expected: the first run prints `Late unmute heard: 2/2` (this is the case that scored 1/2 before the tap existed), the second prints `Late unmute heard: 1/1` or `2/2` depending on participant count, both exit 0. Also re-run the host test and the p2p matrix from Task 3 Step 3; all expectations unchanged.

- [ ] **Step 6: Commit in the tgcalls submodule**

```bash
cd /Users/isaac/build/telegram/telegram-ios/submodules/TgVoipWebrtc/tgcalls
git add tgcalls/group/GroupInstanceReferenceImpl.cpp
git commit -m "group: discover late audio SSRCs from OnUnDemuxableRtpPacket; drop the ICE decorator

RtpTransport already reports every packet RtpDemuxer drops; the vendored
webrtc now forwards that to PeerConnectionObserver::OnUnDemuxableRtpPacket
(tgcalls seam), parsed and SRTP-unprotected, on the network thread. The
reference group engine reads the SSRC there instead of inspecting every
inbound packet through the pass-through MtProtoIceTransport, which is deleted
along with its factory. The mid=0 catch-all frame transformer is unchanged.
tgcalls_cli --mode group --unmute-after keeps scoring 2/2.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Documentation, full iOS build, telegram-ios commit

**Files:**
- Modify `[tgcalls] CLAUDE.md` (section `## mtproto transport on the PeerConnection engines (11.0.0, 18/19)` up to `## Further Context`)
- Modify `submodules/TgVoipWebrtc/CLAUDE.md` (from `### Vendored webrtc patch: "Allow SCTP without DTLS"` up to the line `- 8 third-party BUILD files + 8 build shell scripts …`)
- Modify `submodules/TgVoipWebrtc/BUILD` (already edited in Tasks 2 and 4)
- Commit submodule pointers in telegram-ios

- [ ] **Step 1: Rewrite the tgcalls CLAUDE.md section**

Replace everything from the line `## mtproto transport on the PeerConnection engines (11.0.0, 18/19)` up to but not including `## Further Context` with:

```markdown
## mtproto transport on the PeerConnection engines (11.0.0, 18/19)

`network_use_mtproto` works on `InstanceV2ReferenceImpl` (11.0.0) and
`CallCoreHost` (18/19): full mtproto, zero DTLS, wire bytes identical to 13.0.0
(`mtproto(RTP)`, `mtproto(0xdcdcdcdc || SCTP)`). Default off. Design record:
telegram-ios `docs/superpowers/specs/2026-09-16-tgcalls-mtproto-dtls-slot-design.md`.

**Shape.** Two settings that MUST travel together, both from one boolean:

1. `PeerConnectionFactoryInterface::Options::external_transport_security = true`
   before `CreatePeerConnectionOrError`. A tgcalls seam in the vendored webrtc:
   plain `RtpTransport` (no SRTP) and no SRTP requirement in `BaseChannel`,
   while DTLS stays *enabled* so certificates, fingerprints, `a=setup`, the
   SCTP factory and the data-channel answer are stock.
2. `PeerConnectionDependencies::dtls_transport_factory =
   MtProtoDtlsTransportFactory(key)`. Another seam; it puts
   `v2/MtProtoDtlsTransport` in the DTLS slot.

`MtProtoDtlsTransport` never handshakes (the shared key exists before the call
starts), reports `kConnected` the first time ICE is writable, stores the
certificate and remote fingerprint it is handed and verifies neither, and
answers "no SRTP suite" to anyone who asks. `flags` is ground truth in both
directions, as in 13.0.0's `MtProtoPacketTransport`: `PF_SRTP_BYPASS` (RTP and
RTCP from `BaseChannel`) is framed bare, `0` (SCTP from `DcSctpTransport`) gets
the prefix; on receive the prefix becomes `flags 0` and its absence
`PF_SRTP_BYPASS`, so `DcSctpTransport` (skips `flags != 0`) never parses media.
`SendPacket` returns the CALLER's byte count.

**Why not the obvious routes** (each was shipped or tried and cost a regression):

- `Options::disable_encryption` (2026-09-01 to 2026-09-16). It also turns off
  certificates, fingerprints and the SCTP factory, so three behaviour patches
  in the fork had to put them back, and the SDP one was missing at first: the
  answer rejected the data section on every negotiation and both peers
  renegotiated in a loop for the whole call (6 s loopback: 4,765
  `SetLocalDescription` on 11.0.0 versus 4). That storm was the dominant cause
  of the 2026-09 A/B regression.
- An ICE-level decorator below the inactive `DtlsTransport`. Stock DTLS drops
  `flags` on send and forces 0 on receive, so the decorator had to guess the
  packet type and every media packet was also fed to dcsctp (copy, CRC32c,
  an `LS_ERROR` line each). Its `SendPacket` also returned the ciphertext
  length; `RtpTransport` reads that as a failed send and, with the ICE
  channel's never-cleared ENOTCONN, dropped ready-to-send and paused the
  pacer while packets were going out.
- Subclassing `DtlsSrtpTransport`, subclassing `P2PTransportChannel`,
  socket-level mtproto: see the design record.

**Verification is not "the call connects".** Run
`tgcalls_cli --mode p2p --duration 6 --version {11.0.0,18.0.0,19.0.0}
--custom-params '{"network_use_mtproto":true}' --custom-params2
'{"network_use_mtproto":true}' --log-file …` and require: `Rejected data channel
transport` 0, `SetLocalDescription` 4, `OPEN_ACK` 1, `PARSE_FAILED` 0,
`Creating DtlsSrtpTransport` 0, zero DTLS handshake lines, a log the size of a
plain call (~750 lines / 6 s). `//submodules/TgVoipWebrtc:mtproto_dtls_transport_test`
pins the transport contract over a real `RtpTransport` and `DcSctpTransport`.

```

- [ ] **Step 2: Rewrite the TgVoipWebrtc CLAUDE.md patch sections**

Replace everything from the line `### Vendored webrtc patch: "Allow SCTP without DTLS"` up to but not including the line that begins `- 8 third-party BUILD files + 8 build shell scripts` with:

```markdown
### Vendored webrtc seams for tgcalls (no behaviour patches)

The fork carries three additive, default-off seams, each marked
`TGCALLS SEAM (<consumer>)` in the source. None changes behaviour for a caller
that does not opt in. When bumping webrtc, carry these forward, and drop one
the moment upstream grows an equivalent.

| Seam | Where | Consumer |
|---|---|---|
| `PeerConnectionDependencies::dtls_transport_factory` | `api/peer_connection_interface.h`, `pc/peer_connection.{h,cc}` (plumbed to the `JsepTransportController::Config` field that already existed) | `tgcalls::MtProtoDtlsTransportFactory` |
| `PeerConnectionFactoryInterface::Options::external_transport_security` | `api/peer_connection_interface.h`; `pc/peer_connection.cc` in `InitializeTransportController_n` (`config.disable_encryption`) and `SrtpRequired()` | `InstanceV2ReferenceImpl`, `CallCoreHost` under `network_use_mtproto` |
| `PeerConnectionObserver::OnUnDemuxableRtpPacket(const RtpPacketReceived&)` | `api/peer_connection_interface.h`; `pc/peer_connection.cc` in `InitializeUnDemuxablePacketHandler` (network thread, before the hand-off to `Call`) | `GroupInstanceReferenceImpl` late-speaker SSRC discovery |

History, so nobody reintroduces them: between 2026-09-01 and 2026-09-16 the
fork carried three *behaviour* patches instead ("Allow SCTP without DTLS" in
`pc/peer_connection.cc` and `pc/media_session.cc`, "Inactive DtlsTransport
forwards packet flags" in `p2p/base/dtls_transport.cc`), all consequences of
using `Options::disable_encryption` for mtproto. Engine-side detail and the
regression they caused are in `tgcalls/CLAUDE.md` under "mtproto transport on
the PeerConnection engines"; the design record is
`docs/superpowers/specs/2026-09-16-tgcalls-mtproto-dtls-slot-design.md`.

```

- [ ] **Step 3: Commit the tgcalls docs**

```bash
cd /Users/isaac/build/telegram/telegram-ios/submodules/TgVoipWebrtc/tgcalls
git add CLAUDE.md
git commit -m "docs: mtproto in the DTLS slot; seams instead of patches

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 4: Full iOS simulator build**

```bash
cd /Users/isaac/build/telegram/telegram-ios
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache build --configurationPath build-system/appstore-configuration.json --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64 2>&1 | grep -E "error:|Build completed"
```

Expected: `Build completed successfully`.

- [ ] **Step 5: Commit in telegram-ios**

```bash
cd /Users/isaac/build/telegram/telegram-ios
git add submodules/TgVoipWebrtc/BUILD submodules/TgVoipWebrtc/CLAUDE.md submodules/TgVoipWebrtc/tgcalls third-party/webrtc/webrtc docs/superpowers/plans/2026-09-16-tgcalls-mtproto-dtls-slot.md
git commit -m "tgcalls: mtproto in the DTLS slot with seam-only webrtc patches

Advances the tgcalls and webrtc submodules. MtProtoDtlsTransport replaces the
ICE-level MtProtoIceTransport decorator; the fork's three behaviour patches
(SCTP gate, SDP answer, flags through the inactive DtlsTransport) become three
additive seams (dtls_transport_factory dependency, external_transport_security
option, OnUnDemuxableRtpPacket observer). Group-call late-speaker SSRC
discovery moves to the observer hook. Host test target renamed to
mtproto_dtls_transport_test. Design record in docs/superpowers/specs/
2026-09-16-tgcalls-mtproto-dtls-slot-design.md.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 6: Post-landing checks that this plan does not automate**

A manual mtproto call between two devices (audio and video both ways, one data-channel message each way, a Wi-Fi to cellular switch mid-call), then re-run the A/B. Also update the `tgcalls-mtproto-reference-regression` memory note to "fixed via DTLS-slot redesign, landed <commit>".
