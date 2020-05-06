#include "Connector.h"

#include "Endpoint.h"
#include "Layer92.h"
#include "MediaEngineWebrtc.h"
#include "Protocol10.h"

#include "api/packet_socket_factory.h"
#include "rtc_base/task_utils/to_queued_task.h"

#include <memory>

const int64_t Connector::tcp_reconnect_delay = 5000;
const int64_t Connector::ping_interval_ms = 10000;
const int64_t Connector::endpoint_ping_diff_ms = 20;
const std::set<message::Type> Connector::multicast_types = {
        message::Type::tInit, message::Type::tInitAck, message::Type::tPing
};
const size_t Connector::PingHistory::history_length = 5;
const int64_t Connector::PingHistory::unavailable_ms = 100000;

Connector::PingHistory::PingHistory()
: ping_sum(0)
, sent_id(0)
, sent_time(0) {
    for (size_t i = 0; i < history_length; ++i)
        AppendPing(unavailable_ms);
}

void Connector::PingHistory::AppendPing(int64_t ms) {
    if (history.size() >= history_length) {
        ping_sum -= history.front();
        history.pop();
    }
    if (history.size() < history_length) {
        ping_sum += ms;
        history.emplace(ms);
    }
}

void Connector::PingHistory::UpdatePing(int64_t ms) {
    if (!history.empty()) {
        ping_sum = ping_sum - history.back() + ms;
        history.back() = ms;
    } else
        AppendPing(ms);
}

void Connector::PingHistory::Ping(uint32_t id) {
    sent_id = id;
    sent_time = rtc::TimeMillis();
}

void Connector::PingHistory::Pong(uint32_t id) {
    if (id != sent_id)
        return;
    sent_id = 0;
    UpdatePing(std::min(rtc::TimeMillis() - sent_time, unavailable_ms));
    sent_time = 0;
}

double Connector::PingHistory::Average() {
    return static_cast<double>(ping_sum) / history.size();
}

Connector::Connector(std::unique_ptr<LayerBase> layer)
: active_endpoint(nullptr)
, thread(rtc::Thread::CreateWithSocketServer())
, socket_factory(thread.get())
, layer(std::move(layer))
, ping_seq(0) {
    pinger = webrtc::RepeatingTaskHandle::Start(thread.get(), [this]() {
        Connector::UpdateActiveEndpoint();
        return webrtc::TimeDelta::ms(ping_interval_ms);
    });
}

void Connector::Start() {
    thread->Start();
    thread->Invoke<void>(RTC_FROM_HERE, [this]() {
        socket.reset(socket_factory.CreateUdpSocket(
                rtc::SocketAddress(rtc::GetAnyIP(AF_INET), 0), 0, 0));
        socket->SignalReadPacket.connect(this, &Connector::RecvPacket);
        socket->SignalReadyToSend.connect(this, &Connector::Ready);
    });
}

void Connector::RecvPacket(rtc::AsyncPacketSocket *sock, const char *data, size_t len,
                           const rtc::SocketAddress& remote_addr, const int64_t& packet_time_us) {
    for (const auto& ep : endpoints) {
        auto ep_udp = dynamic_cast<EndpointUdp *>(ep.first);
        if (ep_udp && ep_udp->address == remote_addr) {
            ep_udp->RecvPacket(sock, data, len, remote_addr, packet_time_us);
            break;
        }
    }
}

void Connector::Ready(rtc::AsyncPacketSocket *) {
    SignalMessage(message::Ready());
}

void Connector::AddEndpointRelayTcpObfuscated(const rtc::SocketAddress& addr, const Relay::PeerTag& peer_tag) {
    thread->Invoke<void>(RTC_FROM_HERE, [this, addr, peer_tag]() {
        std::unique_ptr<rtc::AsyncPacketSocket> sock(socket_factory.CreateClientTcpSocket(
                rtc::SocketAddress(rtc::GetAnyIP(AF_INET), 0),
                addr, proxy_info, "", rtc::PacketSocketTcpOptions()));
        AddEndpoint(std::make_unique<EndpointRelayObfuscatedTcp>(std::move(sock), peer_tag, layer.get()));
    });
}

void Connector::AddEndpointRelayUdp(const rtc::SocketAddress& addr, const Relay::PeerTag& peer_tag) {
    thread->Invoke<void>(RTC_FROM_HERE, [this, addr, peer_tag]() {
        assert(socket);
        AddEndpoint(std::make_unique<EndpointRelayUdp>(addr, peer_tag, socket.get(), layer.get()));
    });
}

void Connector::SetEndpointP2p(const rtc::SocketAddress& addr) {
    thread->Invoke<void>(RTC_FROM_HERE, [this, addr]() {
        assert(socket);
        if (auto ep = GetP2pEndpoint())
            DeleteEndpoint(ep);
        AddEndpoint(std::make_unique<EndpointP2p>(addr, socket.get(), layer.get()));
    });
}

Connector::~Connector() {
    thread->Invoke<void>(RTC_FROM_HERE, [this]() {
        pinger.Stop();
        active_endpoint = nullptr;
        endpoints.clear();
        ping_history.clear();
    });
}

void Connector::RecvMessage(const message::Base& msg, EndpointBase *endpoint) {
    if (msg.ID == message::tDisconnected && endpoint->type == EndpointBase::Type::RelayObfuscatedTcp) {
        thread->PostDelayedTask(webrtc::ToQueuedTask([this, endpoint]() {
            if (endpoints.find(endpoint) == endpoints.end())
                return;
            auto final_ep = dynamic_cast<EndpointRelayObfuscatedTcp *>(endpoint);
            if (!final_ep)
                return;
            std::unique_ptr<rtc::AsyncPacketSocket> sock(socket_factory.CreateClientTcpSocket(
                    rtc::SocketAddress(rtc::GetAnyIP(AF_INET), 0),
                    final_ep->address, proxy_info, "", rtc::PacketSocketTcpOptions()));
            final_ep->Reconnect(std::move(sock));
        }), tcp_reconnect_delay);
        if (active_endpoint == endpoint)
            ResetActiveEndpoint();
        return;
    }
    if (auto msg_ping = dynamic_cast<const message::Ping *>(&msg)) {
        message::Pong msg_pong;
        msg_pong.id = msg_ping->id;
        endpoint->SendMessage(msg_pong);
        return;
    }
    if (auto msg_pong = dynamic_cast<const message::Pong *>(&msg)) {
        ping_history[endpoint].Pong(msg_pong->id);
        return;
    }
    // fallback if no active endpoint set
    if (!active_endpoint)
        active_endpoint = endpoint;
    SignalMessage(msg);
}

void Connector::SendMessage(const message::Base& msg) {
    if (!active_endpoint || multicast_types.find(msg.ID) != multicast_types.end()) {
        for (const auto& ep : endpoints) {
            ep.first->SendMessage(msg);
            if (auto msg_ping = dynamic_cast<const message::Ping *>(&msg))
                ping_history[ep.first].Ping(msg_ping->id);
        }
        return;
    }
    active_endpoint->SendMessage(msg);
}

EndpointP2p *Connector::GetP2pEndpoint() const {
    for (const auto& ep : endpoints)
        if (auto ep_p2p = dynamic_cast<EndpointP2p *>(ep.first))
            return ep_p2p;
    return nullptr;
}

void Connector::AddEndpoint(std::unique_ptr<EndpointBase> endpoint) {
    EndpointBase *ep = endpoint.get();
    ep->SignalMessage.connect(this, &Connector::RecvMessage);
    endpoints[ep] = std::move(endpoint);
    ping_history[ep] = PingHistory();
}

void Connector::DeleteEndpoint(EndpointBase *ep) {
    // TODO: must be invoked to thread when become public
    endpoints.erase(ep);
    ping_history.erase(ep);
}

void Connector::ResetActiveEndpoint() {
    active_endpoint = nullptr;
}

void Connector::UpdateActiveEndpoint() {
    if (ping_history.empty())
        return;
    if (ping_history.size() == 1) {
        active_endpoint = ping_history.begin()->first;
        return;
    }
    std::vector<std::pair<double, EndpointBase*>> times;
    for (auto ping : ping_history)
        times.emplace_back(ping.second.Average(), ping.first);
    std::sort(times.begin(), times.end());
    EndpointBase *candidate = times.front().second;
    if (!active_endpoint || (active_endpoint != candidate &&
            ping_history[active_endpoint].Average() - times.front().first > endpoint_ping_diff_ms))
        active_endpoint = candidate;
    message::Ping msg;
    msg.id = ++ping_seq;
    SendMessage(msg);
}

void Connector::SetProxy(rtc::ProxyType type, const rtc::SocketAddress& addr, const std::string& username,
                         const std::string& password) {
    proxy_info.type = type;
    proxy_info.address = addr;
    proxy_info.username = username;
    proxy_info.password = rtc::CryptString();
}
