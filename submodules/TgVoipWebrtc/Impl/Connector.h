#ifndef DEMO_CONNECTOR_H
#define DEMO_CONNECTOR_H


#include "Endpoint.h"
#include "LayerBase.h"
#include "Message.h"

#include "p2p/base/basic_packet_socket_factory.h"
#include "rtc_base/proxy_info.h"
#include "rtc_base/task_utils/repeating_task.h"
#include "rtc_base/third_party/sigslot/sigslot.h"
#include "rtc_base/thread.h"

#include <memory>
#include <map>

class Connector : public sigslot::has_slots<> {
public:
    explicit Connector(std::unique_ptr<LayerBase> layer);
    ~Connector() override;
    void Start();
    void AddEndpointRelayTcpObfuscated(const rtc::SocketAddress& addr, const Relay::PeerTag& peer_tag);
    void AddEndpointRelayUdp(const rtc::SocketAddress& addr, const Relay::PeerTag& peer_tag);
    void SetEndpointP2p(const rtc::SocketAddress& addr);
    sigslot::signal1<const message::Base&> SignalMessage;
    void SendMessage(const message::Base&);
    void ResetActiveEndpoint();
    void SetProxy(rtc::ProxyType type, const rtc::SocketAddress& addr, const std::string& username,
            const std::string& password);

private:
    class PingHistory {
    public:
        PingHistory();
        void Ping(uint32_t id);
        void Pong(uint32_t id);
        double Average();

    private:
        void AppendPing(int64_t ms);
        void UpdatePing(int64_t ms);

        static const size_t history_length;
        static const int64_t unavailable_ms;

        std::queue<int64_t > history;
        int64_t ping_sum;
        uint32_t sent_id;
        int64_t sent_time;
    };

    static const int64_t tcp_reconnect_delay;
    static const int64_t ping_interval_ms;
    static const int64_t endpoint_ping_diff_ms;
    static const std::set<message::Type> multicast_types;

    EndpointP2p *GetP2pEndpoint() const;
    void AddEndpoint(std::unique_ptr<EndpointBase>);
    void DeleteEndpoint(EndpointBase *ep);
    void RecvPacket(rtc::AsyncPacketSocket *socket, const char *data, size_t len,
            const rtc::SocketAddress& remote_addr, const int64_t& packet_time_us);
    void Ready(rtc::AsyncPacketSocket *);
    void RecvMessage(const message::Base&, EndpointBase *);
    void UpdateActiveEndpoint();

    rtc::ProxyInfo proxy_info;
    EndpointBase *active_endpoint;
    std::unique_ptr<rtc::Thread> thread;
    rtc::BasicPacketSocketFactory socket_factory;
    std::unique_ptr<rtc::AsyncPacketSocket> socket;
    std::unique_ptr<LayerBase> layer;
    std::map<EndpointBase *, std::unique_ptr<EndpointBase>> endpoints;
    std::map<EndpointBase *, PingHistory> ping_history;
    webrtc::RepeatingTaskHandle pinger;
    uint32_t ping_seq;
};

#endif //DEMO_CONNECTOR_H
