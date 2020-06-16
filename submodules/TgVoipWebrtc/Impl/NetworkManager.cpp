#include "NetworkManager.h"

#include "p2p/base/basic_packet_socket_factory.h"
#include "p2p/client/basic_port_allocator.h"
#include "p2p/base/p2p_transport_channel.h"
#include "p2p/base/basic_async_resolver_factory.h"
#include "api/packet_socket_factory.h"
#include "rtc_base/task_utils/to_queued_task.h"
#include "p2p/base/ice_credentials_iterator.h"
#include "api/jsep_ice_candidate.h"

#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

NetworkManager::NetworkManager(
    rtc::Thread *thread,
    TgVoipEncryptionKey encryptionKey,
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
    //flags |= cricket::PORTALLOCATOR_DISABLE_UDP;
    _portAllocator->set_flags(_portAllocator->flags() | flags);
    _portAllocator->Initialize();
    
    rtc::SocketAddress defaultStunAddress = rtc::SocketAddress("hlgkfjdrtjfykgulhijkljhulyo.uksouth.cloudapp.azure.com", 3478);
    cricket::ServerAddresses stunServers;
    stunServers.insert(defaultStunAddress);
    std::vector<cricket::RelayServerConfig> turnServers;
    turnServers.push_back(cricket::RelayServerConfig(
        rtc::SocketAddress("hlgkfjdrtjfykgulhijkljhulyo.uksouth.cloudapp.azure.com", 3478),
        "user",
        "root",
        cricket::PROTO_UDP
    ));
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

void NetworkManager::receiveSignalingData(const std::vector<uint8_t> &data) {
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
    rtc::PacketOptions packetOptions;
    _transportChannel->SendPacket((const char *)packet.data(), packet.size(), packetOptions, 0);
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
    _packetReceived(packet);
}

#ifdef TGVOIP_NAMESPACE
}
#endif
