#ifndef DEMO_ENDPOINT_H
#define DEMO_ENDPOINT_H


#include "LayerBase.h"
#include "Message.h"

#include "rtc_base/async_packet_socket.h"
#include "rtc_base/buffer_queue.h"
#include "rtc_base/socket_address.h"

class Connector;

class EndpointBase : public sigslot::has_slots<> {
public:
    enum Type {
        Unknown,
        RelayUdp,
        RelayObfuscatedTcp,
        P2p,
    };

    EndpointBase(const EndpointBase&) = delete;
    virtual void SendMessage(const message::Base&) = 0;
    sigslot::signal2<const message::Base&, EndpointBase *> SignalMessage;
    const Type type;

protected:
    explicit EndpointBase(LayerBase *layer, Type type);
    virtual void RecvPacket(rtc::AsyncPacketSocket *socket, const char *data, size_t len,
            const rtc::SocketAddress& remote_addr, const int64_t& packet_time_us);
    virtual void SendPacket(const uint8_t *data, size_t size) = 0;

    LayerBase *layer;
    rtc::PacketOptions packet_options;
    std::unique_ptr<rtc::ByteBufferReader> in_buffer;
    size_t in_remains;
};

class Relay {
public:
    typedef unsigned char PeerTag[16];

    virtual ~Relay() = default;

protected:
    explicit Relay(const PeerTag& peer_tag);
    bool CheckPacket(rtc::ByteBufferReader *packet);
    const rtc::Buffer& PreparePacket(const rtc::Buffer& packet);

    PeerTag peer_tag;  // how to initialize it in initializer list?

private:
    rtc::Buffer buffer;
};

class EndpointUdp : public EndpointBase {
public:
    const rtc::SocketAddress address;

protected:
    friend class Connector;
//    friend void Connector::RecvPacket(rtc::AsyncPacketSocket *, const char *, size_t,
//            const rtc::SocketAddress&, const int64_t&);

    EndpointUdp(const rtc::SocketAddress& addr, rtc::AsyncPacketSocket *socket, LayerBase *layer, Type type);
    void SendPacket(const uint8_t *data, size_t size) override;

    rtc::AsyncPacketSocket *socket;
};

class EndpointTcp : public EndpointBase {
public:
    const rtc::SocketAddress address;

    void Reconnect(std::unique_ptr<rtc::AsyncPacketSocket> socket_);

protected:
    explicit EndpointTcp(std::unique_ptr<rtc::AsyncPacketSocket> socket, LayerBase *layer, Type type);
    void SendPacket(const uint8_t *data, size_t size) override;

    virtual void Ready(rtc::AsyncPacketSocket *) = 0;
    virtual void Close(rtc::AsyncPacketSocket *, int) = 0;

    std::unique_ptr<rtc::AsyncPacketSocket> socket;
};

class EndpointRelayObfuscatedTcp final : public Relay, public EndpointTcp {
public:
    EndpointRelayObfuscatedTcp(std::unique_ptr<rtc::AsyncPacketSocket> socket, const PeerTag& peer_tag,
            LayerBase *layer);
    void SendMessage(const message::Base&) override;

private:
    void RecvPacket(rtc::AsyncPacketSocket *socket, const char *data, size_t len,
                    const rtc::SocketAddress& remote_addr, const int64_t& packet_time_us) override;
    void Ready(rtc::AsyncPacketSocket *) override;
    void Close(rtc::AsyncPacketSocket *, int) override;
    void SendPacket(const uint8_t *data, size_t size) override;

    TCPO2State recvState;
    TCPO2State sendState;
};

class EndpointRelayUdp final : public Relay, public EndpointUdp {
public:
    EndpointRelayUdp(const rtc::SocketAddress& addr, const PeerTag& peer_tag,
            rtc::AsyncPacketSocket *socket, LayerBase *layer);
    void SendMessage(const message::Base&) override;

private:
    void RecvPacket(rtc::AsyncPacketSocket *socket, const char *data, size_t len,
            const rtc::SocketAddress& remote_addr, const int64_t& packet_time_us) override;
};

class EndpointP2p final : public EndpointUdp {
public:
    EndpointP2p(const rtc::SocketAddress& addr, rtc::AsyncPacketSocket *socket, LayerBase *layer);
    void SendMessage(const message::Base&) override;

private:
    void RecvPacket(rtc::AsyncPacketSocket *socket, const char *data, size_t len,
            const rtc::SocketAddress& remote_addr, const int64_t& packet_time_us) override;
};

#endif //DEMO_ENDPOINT_H
