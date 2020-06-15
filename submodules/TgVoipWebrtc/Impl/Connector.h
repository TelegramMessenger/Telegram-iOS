#ifndef DEMO_CONNECTOR_H
#define DEMO_CONNECTOR_H

#include "p2p/base/basic_packet_socket_factory.h"
#include "rtc_base/proxy_info.h"
#include "rtc_base/task_utils/repeating_task.h"
#include "rtc_base/third_party/sigslot/sigslot.h"
#include "rtc_base/thread.h"

#include "p2p/base/p2p_transport_channel.h"
#include "p2p/client/basic_port_allocator.h"
#include "p2p/base/basic_async_resolver_factory.h"

#include <memory>
#include <map>

class Connector : public sigslot::has_slots<> {
public:
    explicit Connector(bool isOutgoing);
    ~Connector() override;
    void Start();
    
    sigslot::signal1<const std::vector<std::string>&> SignalCandidatesGathered;
    sigslot::signal1<bool> SignalReadyToSendStateChanged;
    sigslot::signal1<const rtc::CopyOnWriteBuffer&> SignalPacketReceived;
    
    void AddRemoteCandidates(const std::vector<std::string> &candidates);
    void SendPacket(const rtc::CopyOnWriteBuffer& data);

private:
    void CandidateGathered(cricket::IceTransportInternal *transport, const cricket::Candidate &candidate);
    void CandidateGatheringState(cricket::IceTransportInternal *transport);
    void TransportStateChanged(cricket::IceTransportInternal *transport);
    void TransportRoleConflict(cricket::IceTransportInternal *transport);
    void TransportReadyToSend(cricket::IceTransportInternal *transport);
    void TransportPacketReceived(rtc::PacketTransportInternal *transport, const char *bytes, size_t size, const int64_t &timestamp, int unused);

    std::unique_ptr<rtc::Thread> networkThread;
    
    bool isOutgoing;
    std::unique_ptr<rtc::BasicPacketSocketFactory> socketFactory;
    std::unique_ptr<rtc::BasicNetworkManager> networkManager;
    std::unique_ptr<cricket::BasicPortAllocator> portAllocator;
    std::unique_ptr<webrtc::BasicAsyncResolverFactory> asyncResolverFactory;
    std::unique_ptr<cricket::P2PTransportChannel> transportChannel;
    
    std::vector<std::string> collectedLocalCandidates;
};

#endif //DEMO_CONNECTOR_H
