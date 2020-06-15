#include "Connector.h"

#include "MediaEngineWebrtc.h"

#include "api/packet_socket_factory.h"
#include "rtc_base/task_utils/to_queued_task.h"
#include "p2p/base/ice_credentials_iterator.h"
#include "api/jsep_ice_candidate.h"

#include <memory>

Connector::Connector(bool isOutgoing) {
    networkThread = rtc::Thread::CreateWithSocketServer();
    
    this->isOutgoing = isOutgoing;
}

Connector::~Connector() {
    networkThread->Invoke<void>(RTC_FROM_HERE, [this]() {
        transportChannel = nullptr;
        asyncResolverFactory = nullptr;
        portAllocator = nullptr;
        networkManager = nullptr;
        socketFactory = nullptr;
    });
}

void Connector::Start() {
    NSLog(@"Started %d", (int)[[NSDate date] timeIntervalSince1970]);
    networkThread->Start();
    
    networkThread->Invoke<void>(RTC_FROM_HERE, [this] {
        socketFactory.reset(new rtc::BasicPacketSocketFactory(networkThread.get()));
        
        networkManager = std::make_unique<rtc::BasicNetworkManager>();
        portAllocator.reset(new cricket::BasicPortAllocator(networkManager.get(), socketFactory.get(), /*turn_customizer=*/ nullptr, /*relay_port_factory=*/ nullptr));
        uint32_t flags = cricket::PORTALLOCATOR_DISABLE_TCP;
        //flags |= cricket::PORTALLOCATOR_DISABLE_UDP;
        portAllocator->set_flags(portAllocator->flags() | flags);
        portAllocator->Initialize();
        
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
        portAllocator->SetConfiguration(stunServers, turnServers, 2, webrtc::NO_PRUNE);
        
        asyncResolverFactory = std::make_unique<webrtc::BasicAsyncResolverFactory>();
        transportChannel.reset(new cricket::P2PTransportChannel("transport", 0, portAllocator.get(), asyncResolverFactory.get(), /*event_log=*/ nullptr));
        
        cricket::IceConfig iceConfig;
        iceConfig.continual_gathering_policy = cricket::GATHER_CONTINUALLY;
        transportChannel->SetIceConfig(iceConfig);
        
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
        
        transportChannel->SetIceParameters(isOutgoing ? localIceParameters : remoteIceParameters);
        transportChannel->SetIceRole(isOutgoing ? cricket::ICEROLE_CONTROLLING : cricket::ICEROLE_CONTROLLED);
        
        transportChannel->SignalCandidateGathered.connect(this, &Connector::CandidateGathered);
        transportChannel->SignalGatheringState.connect(this, &Connector::CandidateGatheringState);
        transportChannel->SignalIceTransportStateChanged.connect(this, &Connector::TransportStateChanged);
        transportChannel->SignalRoleConflict.connect(this, &Connector::TransportRoleConflict);
        transportChannel->SignalReadPacket.connect(this, &Connector::TransportPacketReceived);
        
        transportChannel->MaybeStartGathering();
        
        transportChannel->SetRemoteIceMode(cricket::ICEMODE_FULL);
        transportChannel->SetRemoteIceParameters((!isOutgoing) ? localIceParameters : remoteIceParameters);
    });
}

void Connector::AddRemoteCandidates(const std::vector<std::string> &candidates) {
    networkThread->Invoke<void>(RTC_FROM_HERE, [this, candidates] {
        for (auto &serializedCandidate : candidates) {
            webrtc::JsepIceCandidate parseCandidate("", 0);
            if (parseCandidate.Initialize(serializedCandidate, nullptr)) {
                auto candidate = parseCandidate.candidate();
                printf("Add remote candidate %s\n", serializedCandidate.c_str());
                transportChannel->AddRemoteCandidate(candidate);
            }
        }
    });
}

void Connector::CandidateGathered(cricket::IceTransportInternal *transport, const cricket::Candidate &candidate) {
    assert(networkThread->IsCurrent());
    
    webrtc::JsepIceCandidate iceCandidate("", 0);
    iceCandidate.SetCandidate(candidate);
    std::string serializedCandidate;
    if (iceCandidate.ToString(&serializedCandidate)) {
        std::vector<std::string> arrayOfOne;
        arrayOfOne.push_back(serializedCandidate);
        SignalCandidatesGathered(arrayOfOne);
        
        webrtc::JsepIceCandidate parseCandidate("", 0);
        if (parseCandidate.Initialize(serializedCandidate, nullptr)) {
            auto candidate = parseCandidate.candidate();
            
        }
    }
}

void Connector::CandidateGatheringState(cricket::IceTransportInternal *transport) {
    if (transport->gathering_state() == cricket::IceGatheringState::kIceGatheringComplete) {
        /*if (collectedLocalCandidates.size() != 0) {
            SignalCandidatesGathered(collectedLocalCandidates);
        }*/
    }
}

void Connector::TransportStateChanged(cricket::IceTransportInternal *transport) {
    auto state = transport->GetIceTransportState();
    switch (state) {
        case webrtc::IceTransportState::kConnected:
        case webrtc::IceTransportState::kCompleted:
            SignalReadyToSendStateChanged(true);
            printf("===== State: Connected\n");
            break;
        default:
            SignalReadyToSendStateChanged(false);
            printf("===== State: Disconnected\n");
            break;
    }
}

void Connector::TransportRoleConflict(cricket::IceTransportInternal *transport) {
    printf("===== Role conflict\n");
}

void Connector::TransportPacketReceived(rtc::PacketTransportInternal *transport, const char *bytes, size_t size, const int64_t &timestamp, __unused int unused) {
    rtc::CopyOnWriteBuffer data;
    data.AppendData(bytes, size);
    SignalPacketReceived(data);
}

void Connector::SendPacket(const rtc::CopyOnWriteBuffer& data) {
    networkThread->Invoke<void>(RTC_FROM_HERE, [this, data] {
        rtc::PacketOptions options;
        transportChannel->SendPacket((const char *)data.data(), data.size(), options, 0);
    });
}
