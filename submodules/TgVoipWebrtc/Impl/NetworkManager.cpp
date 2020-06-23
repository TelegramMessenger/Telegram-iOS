#include "NetworkManager.h"

#include "p2p/base/basic_packet_socket_factory.h"
#include "p2p/client/basic_port_allocator.h"
#include "p2p/base/p2p_transport_channel.h"
#include "p2p/base/basic_async_resolver_factory.h"
#include "api/packet_socket_factory.h"
#include "rtc_base/task_utils/to_queued_task.h"
#include "p2p/base/ice_credentials_iterator.h"
#include "api/jsep_ice_candidate.h"

extern "C" {
#include <openssl/sha.h>
#include <openssl/aes.h>
#include <openssl/modes.h>
#include <openssl/rand.h>
#include <openssl/crypto.h>
}

#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

static void KDF2(unsigned char *encryptionKey, unsigned char *msgKey, size_t x, unsigned char *aesKey, unsigned char *aesIv) {
    uint8_t sA[32], sB[32];
    uint8_t buf[16 + 36];
    memcpy(buf, msgKey, 16);
    memcpy(buf + 16, encryptionKey + x, 36);
    SHA256(buf, 16 + 36, sA);
    memcpy(buf, encryptionKey + 40 + x, 36);
    memcpy(buf + 36, msgKey, 16);
    SHA256(buf, 36 + 16, sB);
    memcpy(aesKey, sA, 8);
    memcpy(aesKey + 8, sB + 8, 16);
    memcpy(aesKey + 8 + 16, sA + 24, 8);
    memcpy(aesIv, sB, 8);
    memcpy(aesIv + 8, sA + 8, 16);
    memcpy(aesIv + 8 + 16, sB + 24, 8);
}

static void aesIgeEncrypt(uint8_t *in, uint8_t *out, size_t length, uint8_t *key, uint8_t *iv) {
    AES_KEY akey;
    AES_set_encrypt_key(key, 32*8, &akey);
    AES_ige_encrypt(in, out, length, &akey, iv, AES_ENCRYPT);
}

static void aesIgeDecrypt(uint8_t *in, uint8_t *out, size_t length, uint8_t *key, uint8_t *iv) {
    AES_KEY akey;
    AES_set_decrypt_key(key, 32*8, &akey);
    AES_ige_encrypt(in, out, length, &akey, iv, AES_DECRYPT);
}

static absl::optional<rtc::CopyOnWriteBuffer> decryptPacket(const rtc::CopyOnWriteBuffer &packet, const TgVoipEncryptionKey &encryptionKey) {
    if (packet.size() < 16 + 16) {
        return absl::nullopt;
    }
    unsigned char msgKey[16];
    memcpy(msgKey, packet.data(), 16);
    
    int x = encryptionKey.isOutgoing ? 8 : 0;

    unsigned char aesKey[32];
    unsigned char aesIv[32];
    KDF2((unsigned char *)encryptionKey.value.data(), msgKey, x, aesKey, aesIv);
    size_t decryptedSize = packet.size() - 16;
    if (decryptedSize < 0 || decryptedSize > 128 * 1024) {
        return absl::nullopt;
    }
    if (decryptedSize % 16 != 0) {
        return absl::nullopt;
    }
    rtc::Buffer decryptionBuffer(decryptedSize);
    aesIgeDecrypt(((uint8_t *)packet.data()) + 16, decryptionBuffer.begin(), decryptionBuffer.size(), aesKey, aesIv);
    
    rtc::ByteBufferWriter msgKeyData;
    msgKeyData.WriteBytes((const char *)encryptionKey.value.data() + 88 + x, 32);
    msgKeyData.WriteBytes((const char *)decryptionBuffer.data(), decryptionBuffer.size());
    unsigned char msgKeyLarge[32];
    SHA256((uint8_t *)msgKeyData.Data(), msgKeyData.Length(), msgKeyLarge);
    
    uint16_t innerSize;
    memcpy(&innerSize, decryptionBuffer.data(), 2);
    
    unsigned char checkMsgKey[16];
    memcpy(checkMsgKey, msgKeyLarge + 8, 16);
    
    if (memcmp(checkMsgKey, msgKey, 16) != 0) {
        return absl::nullopt;
    }
    
    if (innerSize < 0 || innerSize > decryptionBuffer.size() - 2) {
        return absl::nullopt;
    }
    
    rtc::CopyOnWriteBuffer decryptedPacket;
    decryptedPacket.AppendData((const char *)decryptionBuffer.data() + 2, innerSize);
    return decryptedPacket;
}

static absl::optional<rtc::Buffer> encryptPacket(const rtc::CopyOnWriteBuffer &packet, const TgVoipEncryptionKey &encryptionKey) {
    if (packet.size() > UINT16_MAX) {
        return absl::nullopt;
    }
    
    rtc::ByteBufferWriter innerData;
    uint16_t packetSize = (uint16_t)packet.size();
    innerData.WriteBytes((const char *)&packetSize, 2);
    innerData.WriteBytes((const char *)packet.data(), packet.size());
    
    size_t innerPadding = 16 - innerData.Length() % 16;
    uint8_t paddingData[16];
    RAND_bytes(paddingData, (int)innerPadding);
    innerData.WriteBytes((const char *)paddingData, innerPadding);
    
    if (innerData.Length() % 16 != 0) {
        assert(false);
        return absl::nullopt;
    }
    
    int x = encryptionKey.isOutgoing ? 0 : 8;
    
    rtc::ByteBufferWriter msgKeyData;
    msgKeyData.WriteBytes((const char *)encryptionKey.value.data() + 88 + x, 32);
    msgKeyData.WriteBytes(innerData.Data(), innerData.Length());
    unsigned char msgKeyLarge[32];
    SHA256((uint8_t *)msgKeyData.Data(), msgKeyData.Length(), msgKeyLarge);
    
    unsigned char msgKey[16];
    memcpy(msgKey, msgKeyLarge + 8, 16);
    
    unsigned char aesKey[32];
    unsigned char aesIv[32];
    KDF2((unsigned char *)encryptionKey.value.data(), msgKey, x, aesKey, aesIv);
    
    rtc::Buffer encryptedPacket;
    encryptedPacket.AppendData((const char *)msgKey, 16);
    
    rtc::Buffer encryptionBuffer(innerData.Length());
    aesIgeEncrypt((uint8_t *)innerData.Data(), encryptionBuffer.begin(), innerData.Length(), aesKey, aesIv);
    
    encryptedPacket.AppendData(encryptionBuffer.begin(), encryptionBuffer.size());
    
    /*rtc::CopyOnWriteBuffer testBuffer;
    testBuffer.AppendData(encryptedPacket.data(), encryptedPacket.size());
    TgVoipEncryptionKey testKey;
    testKey.value = encryptionKey.value;
    testKey.isOutgoing = !encryptionKey.isOutgoing;
    decryptPacket(testBuffer, testKey);*/
    
    return encryptedPacket;
}

NetworkManager::NetworkManager(
    rtc::Thread *thread,
    TgVoipEncryptionKey encryptionKey,
    bool enableP2P,
    std::vector<TgVoipRtcServer> const &rtcServers,
    std::function<void (const NetworkManager::State &)> stateUpdated,
    std::function<void (const rtc::CopyOnWriteBuffer &)> packetReceived,
    std::function<void (const std::vector<uint8_t> &)> signalingDataEmitted
) :
_thread(thread),
_encryptionKey(encryptionKey),
_stateUpdated(stateUpdated),
_packetReceived(packetReceived),
_signalingDataEmitted(signalingDataEmitted) {
    assert(_thread->IsCurrent());
    
    _socketFactory.reset(new rtc::BasicPacketSocketFactory(_thread));
    
    _networkManager = std::make_unique<rtc::BasicNetworkManager>();
    _portAllocator.reset(new cricket::BasicPortAllocator(_networkManager.get(), _socketFactory.get(), nullptr, nullptr));
    
    uint32_t flags = cricket::PORTALLOCATOR_DISABLE_TCP;
    if (!enableP2P) {
        flags |= cricket::PORTALLOCATOR_DISABLE_UDP;
        flags |= cricket::PORTALLOCATOR_DISABLE_STUN;
    }
    _portAllocator->set_flags(_portAllocator->flags() | flags);
    _portAllocator->Initialize();
    
    cricket::ServerAddresses stunServers;
    std::vector<cricket::RelayServerConfig> turnServers;
    
    if (rtcServers.size() == 0 || rtcServers[0].host == "hlgkfjdrtjfykgulhijkljhulyo.uksouth.cloudapp.azure.com") {
        rtc::SocketAddress defaultStunAddress = rtc::SocketAddress("134.122.52.178", 3478);
        stunServers.insert(defaultStunAddress);
        
        turnServers.push_back(cricket::RelayServerConfig(
            rtc::SocketAddress("134.122.52.178", 3478),
            "openrelay",
            "openrelay",
            cricket::PROTO_UDP
        ));
    } else {
        for (auto &server : rtcServers) {
            if (server.isTurn) {
                turnServers.push_back(cricket::RelayServerConfig(
                    rtc::SocketAddress(server.host, server.port),
                    server.login,
                    server.password,
                    cricket::PROTO_UDP
                ));
            } else {
                rtc::SocketAddress stunAddress = rtc::SocketAddress(server.host, server.port);
                stunServers.insert(stunAddress);
            }
        }
    }
    
    _portAllocator->SetConfiguration(stunServers, turnServers, 2, webrtc::NO_PRUNE);
    
    _asyncResolverFactory = std::make_unique<webrtc::BasicAsyncResolverFactory>();
    _transportChannel.reset(new cricket::P2PTransportChannel("transport", 0, _portAllocator.get(), _asyncResolverFactory.get(), nullptr));
    
    cricket::IceConfig iceConfig;
    iceConfig.continual_gathering_policy = cricket::GATHER_CONTINUALLY;
    _transportChannel->SetIceConfig(iceConfig);
    
    cricket::IceParameters localIceParameters(
        "gcp3",
        "zWDKozH8/3JWt8he3M/CMj5R",
        false
    );
    cricket::IceParameters remoteIceParameters(
        "acp3",
        "aWDKozH8/3JWt8he3M/CMj5R",
        false
    );
    
    _transportChannel->SetIceParameters(_encryptionKey.isOutgoing ? localIceParameters : remoteIceParameters);
    _transportChannel->SetIceRole(_encryptionKey.isOutgoing ? cricket::ICEROLE_CONTROLLING : cricket::ICEROLE_CONTROLLED);
    
    _transportChannel->SignalCandidateGathered.connect(this, &NetworkManager::candidateGathered);
    _transportChannel->SignalGatheringState.connect(this, &NetworkManager::candidateGatheringState);
    _transportChannel->SignalIceTransportStateChanged.connect(this, &NetworkManager::transportStateChanged);
    _transportChannel->SignalReadPacket.connect(this, &NetworkManager::transportPacketReceived);
    
    _transportChannel->MaybeStartGathering();
    
    _transportChannel->SetRemoteIceMode(cricket::ICEMODE_FULL);
    _transportChannel->SetRemoteIceParameters((!_encryptionKey.isOutgoing) ? localIceParameters : remoteIceParameters);
}

NetworkManager::~NetworkManager() {
    assert(_thread->IsCurrent());
    
    _transportChannel.reset();
    _asyncResolverFactory.reset();
    _portAllocator.reset();
    _networkManager.reset();
    _socketFactory.reset();
}

void NetworkManager::receiveSignalingData(const rtc::CopyOnWriteBuffer &data) {
    rtc::ByteBufferReader reader((const char *)data.data(), data.size());
    uint32_t candidateCount = 0;
    if (!reader.ReadUInt32(&candidateCount)) {
        return;
    }
    std::vector<std::string> candidates;
    for (uint32_t i = 0; i < candidateCount; i++) {
        uint32_t candidateLength = 0;
        if (!reader.ReadUInt32(&candidateLength)) {
            return;
        }
        std::string candidate;
        if (!reader.ReadString(&candidate, candidateLength)) {
            return;
        }
        candidates.push_back(candidate);
    }
    
    for (auto &serializedCandidate : candidates) {
        webrtc::JsepIceCandidate parseCandidate("", 0);
        if (parseCandidate.Initialize(serializedCandidate, nullptr)) {
            auto parsedCandidate = parseCandidate.candidate();
            _transportChannel->AddRemoteCandidate(parsedCandidate);
        }
    }
}

void NetworkManager::sendPacket(const rtc::CopyOnWriteBuffer &packet) {
    auto encryptedPacket = encryptPacket(packet, _encryptionKey);
    if (encryptedPacket.has_value()) {
        rtc::PacketOptions packetOptions;
        _transportChannel->SendPacket((const char *)encryptedPacket->data(), encryptedPacket->size(), packetOptions, 0);
    }
}

void NetworkManager::candidateGathered(cricket::IceTransportInternal *transport, const cricket::Candidate &candidate) {
    assert(_thread->IsCurrent());
    webrtc::JsepIceCandidate iceCandidate("", 0);
    iceCandidate.SetCandidate(candidate);
    std::string serializedCandidate;
    if (!iceCandidate.ToString(&serializedCandidate)) {
        return;
    }
    std::vector<std::string> candidates;
    candidates.push_back(serializedCandidate);
    
    rtc::ByteBufferWriter writer;
    writer.WriteUInt32((uint32_t)candidates.size());
    for (auto string : candidates) {
        writer.WriteUInt32((uint32_t)string.size());
        writer.WriteString(string);
    }
    std::vector<uint8_t> data;
    data.resize(writer.Length());
    memcpy(data.data(), writer.Data(), writer.Length());
    _signalingDataEmitted(data);
}

void NetworkManager::candidateGatheringState(cricket::IceTransportInternal *transport) {
    assert(_thread->IsCurrent());
}

void NetworkManager::transportStateChanged(cricket::IceTransportInternal *transport) {
    assert(_thread->IsCurrent());
    
    auto state = transport->GetIceTransportState();
    bool isConnected = false;
    switch (state) {
        case webrtc::IceTransportState::kConnected:
        case webrtc::IceTransportState::kCompleted:
            isConnected = true;
            break;
        default:
            break;
    }
    NetworkManager::State emitState;
    emitState.isReadyToSendData = isConnected;
    _stateUpdated(emitState);
}

void NetworkManager::transportReadyToSend(cricket::IceTransportInternal *transport) {
    assert(_thread->IsCurrent());
}

void NetworkManager::transportPacketReceived(rtc::PacketTransportInternal *transport, const char *bytes, size_t size, const int64_t &timestamp, int unused) {
    assert(_thread->IsCurrent());
    rtc::CopyOnWriteBuffer packet;
    packet.AppendData(bytes, size);
    
    auto decryptedPacket = decryptPacket(packet, _encryptionKey);
    if (decryptedPacket.has_value()) {
        _packetReceived(decryptedPacket.value());
    }
}

#ifdef TGVOIP_NAMESPACE
}
#endif
