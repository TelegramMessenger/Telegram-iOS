#include "Endpoint.h"

#include "rtc_base/buffer.h"
#include "rtc_base/byte_buffer.h"

#include <memory>
#include <queue>

EndpointBase::EndpointBase(LayerBase *layer, Type type)
: type(type)
, layer(layer)
, in_buffer(std::make_unique<rtc::ByteBufferReader>(nullptr, 0))
, in_remains(0) {}

void EndpointBase::RecvPacket(rtc::AsyncPacketSocket *, const char *data, size_t len,
        const rtc::SocketAddress& remote_addr, const int64_t& packet_time_us) {
    if (in_buffer && in_buffer->Length() > 0) {
        rtc::Buffer tmp(in_buffer->Data(), in_buffer->Length() + len);
        memcpy(tmp.data() + in_buffer->Length(), data, len);
        in_buffer = std::make_unique<rtc::ByteBufferReader>(reinterpret_cast<const char *>(tmp.data()), tmp.size());
    } else
        in_buffer = std::make_unique<rtc::ByteBufferReader>(data, len);
}

EndpointUdp::EndpointUdp(const rtc::SocketAddress& addr, rtc::AsyncPacketSocket *socket, LayerBase *layer, Type type)
: EndpointBase(layer, type)
, address(addr)
, socket(socket) {}

void EndpointUdp::SendPacket(const uint8_t *data, size_t size) {
    socket->SendTo(data, size, address, packet_options);
}

EndpointTcp::EndpointTcp(std::unique_ptr<rtc::AsyncPacketSocket> socket, LayerBase *layer, Type type)
: EndpointBase(layer, type)
, address(socket->GetRemoteAddress())
, socket(nullptr) {
    Reconnect(std::move(socket));
}

void EndpointTcp::Reconnect(std::unique_ptr<rtc::AsyncPacketSocket> socket_) {
    socket = std::move(socket_);
    socket->SignalReadPacket.connect(dynamic_cast<EndpointBase *>(this), &EndpointTcp::RecvPacket);
    socket->SignalReadyToSend.connect(this, &EndpointTcp::Ready);
    socket->SignalClose.connect(this, &EndpointTcp::Close);
}

void EndpointTcp::SendPacket(const uint8_t *data, size_t size) {
    socket->Send(data, size, packet_options);
}

Relay::Relay(const PeerTag& peer_tag_) : peer_tag() {
    memcpy(peer_tag, peer_tag_, sizeof(PeerTag));
}

bool Relay::CheckPacket(rtc::ByteBufferReader *packet) {
    if (packet->Length() >= 16 && memcmp(peer_tag, packet->Data(), 16) == 0) {
        packet->Consume(16);
        return true;
    }
    return false;
}

const rtc::Buffer& Relay::PreparePacket(const rtc::Buffer& packet) {
    buffer.Clear();
    if (!packet.empty()) {
        buffer.AppendData(peer_tag, 16);
        buffer.AppendData(packet);
    }
    return buffer;
}

EndpointRelayObfuscatedTcp::EndpointRelayObfuscatedTcp(std::unique_ptr<rtc::AsyncPacketSocket> socket,
        const PeerTag& peer_tag, LayerBase *layer)
: Relay(peer_tag)
, EndpointTcp(std::move(socket), layer, Type::RelayObfuscatedTcp)
, recvState()
, sendState() {}

void EndpointRelayObfuscatedTcp::Ready(rtc::AsyncPacketSocket *) {
    unsigned char buf[64];
    layer->GenerateTCPO2States(buf, &recvState, &sendState);
    EndpointTcp::SendPacket(buf, 64);
    SignalMessage(message::Connected(), this);
}

void EndpointRelayObfuscatedTcp::Close(rtc::AsyncPacketSocket *, int) {
    SignalMessage(message::Disconnected(), this);
}

void EndpointRelayObfuscatedTcp::RecvPacket(rtc::AsyncPacketSocket *socket, const char *data, size_t packet_len,
        const rtc::SocketAddress& remote_addr, const int64_t& packet_time_us) {
    EndpointBase::RecvPacket(socket, data, packet_len, remote_addr, packet_time_us);
    do {
        if (in_remains > in_buffer->Length())
            break;
        if (in_remains > 0 && CheckPacket(in_buffer.get())) {
            auto msg = layer->DecodePacket(*in_buffer);
            if (msg)
                SignalMessage(*msg, this);
        }

        unsigned char len1;
        size_t packetLen = 0;
        if (!in_buffer->ReadUInt8(&len1))
            break;
        layer->EncryptForTCPO2(&len1, 1, &recvState);
        if (len1 < 0x7F) {
            packetLen = (size_t) len1 * 4;
        } else {
            unsigned char len2[3];
            if (!in_buffer->ReadBytes(reinterpret_cast<char *>(&len2), 3)) {
                SignalMessage(message::PacketIncorrect(), this);
                return;
            }
            layer->EncryptForTCPO2(len2, 3, &recvState);
            packetLen = ((size_t) len2[0] | ((size_t) len2[1] << 8) | ((size_t) len2[2] << 16)) * 4;
        }

        in_remains = packetLen;
        if (packetLen > in_buffer->Length()) {
            in_remains = packetLen;
            break;
        }
    } while (true);
}

void EndpointRelayObfuscatedTcp::SendMessage(const message::Base& msg_base) {
    if (socket->GetState() == rtc::AsyncPacketSocket::State::STATE_CLOSED)
        return;
    const rtc::Buffer& out = PreparePacket(layer->EncodePacket(&msg_base));
    if (!out.empty())
        SendPacket(out.data(), out.size());
}

void EndpointRelayObfuscatedTcp::SendPacket(const uint8_t *data, size_t size) {
    rtc::ByteBufferWriter out;
    size_t len = size / 4;
    if (len < 0x7F) {
        out.WriteUInt8(len);
    } else {
        out.WriteUInt8(0x7F);
        out.WriteUInt8(len & 0xFF);
        out.WriteUInt8((len >> 8) & 0xFF);
        out.WriteUInt8((len >> 16) & 0xFF);
    }
    out.WriteBytes(reinterpret_cast<const char *>(data), size);
    layer->EncryptForTCPO2(reinterpret_cast<unsigned char *>(out.ReserveWriteBuffer(0)),
            out.Length(), &sendState);
    EndpointTcp::SendPacket(reinterpret_cast<const uint8_t *>(out.Data()), out.Length());
}

EndpointRelayUdp::EndpointRelayUdp(const rtc::SocketAddress& addr, const PeerTag& peer_tag,
        rtc::AsyncPacketSocket *socket, LayerBase *layer)
        : Relay(peer_tag)
        , EndpointUdp(addr, socket, layer, Type::RelayUdp) {}

void EndpointRelayUdp::SendMessage(const message::Base& msg_base) {
    const rtc::Buffer& out = PreparePacket(layer->EncodePacket(&msg_base));
    if (!out.empty())
        SendPacket(out.data(), out.size());
}

void EndpointRelayUdp::RecvPacket(rtc::AsyncPacketSocket *sock, const char *data, size_t len,
        const rtc::SocketAddress& remote_addr, const int64_t& packet_time_us) {
    bool glued;
    bool processed = false;
    do {
        EndpointBase::RecvPacket(sock, data, len, remote_addr, packet_time_us);
        glued = in_buffer->Length() > len;
        std::unique_ptr<message::Base> msg;
        while (CheckPacket(in_buffer.get()) && (msg = layer->DecodePacket(*in_buffer))) {
            processed = true;
            SignalMessage(*msg, this);
        }
        if (!processed)
            in_buffer = std::make_unique<rtc::ByteBufferReader>(nullptr, 0);
    } while (!processed && glued);
}

EndpointP2p::EndpointP2p(const rtc::SocketAddress& addr, rtc::AsyncPacketSocket *socket, LayerBase *layer)
: EndpointUdp(addr, socket, layer, Type::P2p) {}

void EndpointP2p::SendMessage(const message::Base& msg_base) {
    rtc::Buffer out = layer->EncodePacket(&msg_base);
    if (!out.empty())
        SendPacket(out.data(), out.size());
}

void EndpointP2p::RecvPacket(rtc::AsyncPacketSocket *sock, const char *data, size_t len,
        const rtc::SocketAddress& remote_addr, const int64_t& packet_time_us) {
    bool glued;
    bool processed = false;
    do {
        EndpointBase::RecvPacket(sock, data, len, remote_addr, packet_time_us);
        glued = in_buffer->Length() > len;
        while (auto msg = layer->DecodePacket(*in_buffer)) {
            processed = true;
            SignalMessage(*msg, this);
        }
        if (!processed)
            in_buffer = std::make_unique<rtc::ByteBufferReader>(nullptr, 0);
    } while (!processed && glued);
}
