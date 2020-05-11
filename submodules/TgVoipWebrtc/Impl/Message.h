#ifndef DEMO_MESSAGE_H
#define DEMO_MESSAGE_H

#include "rtc_base/copy_on_write_buffer.h"
#include "rtc_base/socket_address.h"

namespace message {

enum Type {
    tUnknown,
    tReady,
    tConnected,
    tDisconnected,
    tRelayPing,
    tRelayPong,
    tGetPeerInfo,
    tPeerInfo,
    tSelfIPv6,
    tSelfLocalIP,
    tInit,
    tInitAck,
    tPing,
    tPong,
    tBufferOverflow,
    tPacketIncorrect,
    tWrongProtocol,
    tRtpStream,
};

enum NetworkType {
    nGprs,
    nEdge,
    n3gOrAbove,
    nHighSpeed,
    nUnknown,
};

struct Base {
    virtual ~Base() = default;
    explicit Base(Type ID) : ID(ID) {}
    const Type ID;
};

struct Unknown : Base {
    Unknown() : Base(Type::tUnknown) {}
};

struct Ready : Base {
    Ready() : Base(Type::tReady) {}
};

struct Connected : Base {
    Connected() : Base(Type::tConnected) {}
};

struct Disconnected : Base {
    Disconnected() : Base(Type::tDisconnected) {}
};

struct RelayPing : Base {
    RelayPing() : Base(Type::tRelayPing) {}
};

struct RelayPong : Base {
    RelayPong() : Base(Type::tRelayPong) {}
    uint32_t date{};  // int32_t in src
    uint64_t query_id{};  //int64_t in src
    rtc::SocketAddress my_addr;
};

struct GetPeerInfo : Base {
    GetPeerInfo() : Base(Type::tGetPeerInfo) {}
};

struct PeerInfo : Base {
    PeerInfo() : Base(Type::tPeerInfo) {}
    rtc::SocketAddress my_addr;
    rtc::SocketAddress peer_addr;
};

struct SelfIPv6 : Base {
    SelfIPv6() : Base(Type::tSelfIPv6) {}
    rtc::SocketAddress my_addr;
};

struct SelfLocalIP : Base {
    SelfLocalIP() : Base(Type::tSelfLocalIP) {}
};

struct Init : Base {
    Init() : Base(Type::tInit) {}
    uint32_t ver{};
    uint32_t minVer{};
    uint32_t flags{};
};

struct InitAck : Base {
    InitAck() : Base(Type::tInitAck) {}
    uint32_t ver{};
    uint32_t minVer{};
};

struct Ping : Base {
    Ping() : Base(Type::tPing) {}
    uint32_t id{};
};

struct Pong : Base {
    Pong() : Base(Type::tPong) {}
    uint32_t id{};
};

struct BufferOverflow : Base {
    BufferOverflow() : Base(Type::tBufferOverflow) {}
};

struct PacketIncorrect : Base {
    PacketIncorrect() : Base(Type::tPacketIncorrect) {}
};

struct WrongProtocol : Base {
    WrongProtocol() : Base(Type::tWrongProtocol) {}
};

struct RtpStream : Base {
    RtpStream() : Base(Type::tRtpStream) {}
    bool data_saving{false};
    NetworkType network_type{NetworkType::nUnknown};
    rtc::CopyOnWriteBuffer data;
};

}

#endif //DEMO_MESSAGE_H
