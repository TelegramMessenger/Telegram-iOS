#include "Protocol10.h"

#include "rtc_base/byte_buffer.h"

#include <functional>
#include <map>

const std::map<uint8_t, Protocol10::Deserializer> Protocol10::decoders = {
        {Protocol10::PacketType::tInit, Protocol10::InitDecode},  // back compatibility
        {Protocol10::PacketType::tInitAck, Protocol10::InitAckDecode},  // back compatibility
        {Protocol10::PacketType::tRtpStream, Protocol10::RtpStreamDecode},
        {Protocol10::PacketType::tPing, Protocol10::PingDecode},
        {Protocol10::PacketType::tPong, Protocol10::PongDecode},
};

const std::map<uint8_t, Protocol10::Serializer> Protocol10::encoders = {
        {message::tInit, Protocol10::InitEncode},
        {message::tInitAck, Protocol10::InitAckEncode},
        {message::tRtpStream, Protocol10::RtpStreamEncode},
        {message::tPing, Protocol10::PingEncode},
        {message::tPong, Protocol10::PongEncode},
};

Protocol10::Protocol10() : ProtocolBase(10) {}

std::unique_ptr<message::Base> Protocol10::ReadProtocolPacket(const uint8_t *buffer, size_t size) {
    uint8_t type = buffer[0];
    auto deserializer = decoders.find(type);
    if (deserializer == decoders.end())
        return nullptr;
    return deserializer->second(buffer + 1, size - 1);
}

rtc::Buffer Protocol10::WriteProtocolPacket(const message::Base *msg) {
    auto serializer = encoders.find(msg->ID);
    if (serializer == encoders.end())
        return rtc::Buffer();
    return serializer->second(msg);
}

rtc::Buffer Protocol10::InitEncode(const message::Base *msg_base) {
    const auto *msg = dynamic_cast<const message::Init *>(msg_base);
    if (!msg)
        return rtc::Buffer();
    rtc::ByteBufferWriter out;
    out.WriteUInt8(PacketType::tInit);
    out.Resize(14);
    out.WriteUInt32(rtc::NetworkToHost32(msg->ver));
    out.WriteUInt32(rtc::NetworkToHost32(msg->minVer));
    out.WriteUInt32(rtc::NetworkToHost32(msg->flags));
    return rtc::Buffer(out.Data(), out.Length());
}

std::unique_ptr<message::Base> Protocol10::InitDecode(const uint8_t *buffer, size_t size) {
    rtc::ByteBufferReader in(reinterpret_cast<const char *>(buffer), size);
    uint32_t ackId = 0, pseq = 0, acks = 0;
    unsigned char pflags = 0;
    in.ReadUInt32(&ackId);
    in.ReadUInt32(&pseq);
    in.ReadUInt32(&acks);
    in.ReadUInt8(&pflags);
    auto msg = std::make_unique<message::Init>();
    in.ReadUInt32(&msg->ver);
    in.ReadUInt32(&msg->minVer);
    in.ReadUInt32(&msg->flags);
    msg->ver = rtc::HostToNetwork32(msg->ver);
    msg->minVer = rtc::HostToNetwork32(msg->minVer);
    msg->flags = rtc::HostToNetwork32(msg->flags);
    if (ProtocolBase::IsSupported(msg->ver))
        return msg;
    // TODO: support matching of lower supported versions
    return std::make_unique<message::WrongProtocol>();
}

rtc::Buffer Protocol10::InitAckEncode(const message::Base *msg_base) {
    const auto *msg = dynamic_cast<const message::InitAck *>(msg_base);
    if (!msg)
        return rtc::Buffer();
    rtc::ByteBufferWriter out;
    out.WriteUInt8(PacketType::tInitAck);
    out.Resize(14);
    out.WriteUInt32(rtc::NetworkToHost32(msg->ver));
    out.WriteUInt32(rtc::NetworkToHost32(msg->minVer));
    return rtc::Buffer(out.Data(), out.Length());
}

std::unique_ptr<message::Base> Protocol10::InitAckDecode(const uint8_t *buffer, size_t size) {
    rtc::ByteBufferReader in(reinterpret_cast<const char *>(buffer), size);
    uint32_t ackId = 0, pseq = 0, acks = 0;
    unsigned char pflags = 0;
    in.ReadUInt32(&ackId);
    in.ReadUInt32(&pseq);
    in.ReadUInt32(&acks);
    in.ReadUInt8(&pflags);
    auto msg = std::make_unique<message::InitAck>();
    in.ReadUInt32(&msg->ver);
    in.ReadUInt32(&msg->minVer);
    msg->ver = rtc::HostToNetwork32(msg->ver);
    msg->minVer = rtc::HostToNetwork32(msg->minVer);
    if (ProtocolBase::IsSupported(msg->ver))
        return msg;
    // TODO: support matching of lower supported versions
    return std::make_unique<message::WrongProtocol>();
}

rtc::Buffer Protocol10::RtpStreamEncode(const message::Base *msg_base) {
    const auto *msg = dynamic_cast<const message::RtpStream *>(msg_base);
    if (!msg)
        return rtc::Buffer();
    rtc::ByteBufferWriter out;
    out.WriteUInt8(PacketType::tRtpStream);
    uint8_t meta = (msg->network_type & 0b111) | (msg->data_saving << 3);
    out.WriteUInt8(meta);
    out.WriteBytes(reinterpret_cast<const char *>(msg->data.data()), msg->data.size());
    return rtc::Buffer(out.Data(), out.Length());
}

std::unique_ptr<message::Base> Protocol10::RtpStreamDecode(const uint8_t *buffer, size_t size) {
    auto msg = std::make_unique<message::RtpStream>();
    uint8_t meta =  buffer[0];
    msg->network_type = (message::NetworkType) (meta & 0b111);
    msg->data_saving = (meta >> 3) & 0b1;
    msg->data = rtc::CopyOnWriteBuffer(buffer + 1, size - 1);
    return msg;
}

rtc::Buffer Protocol10::PingEncode(const message::Base *msg_base) {
    const auto *msg = dynamic_cast<const message::Ping *>(msg_base);
    if (!msg)
        return rtc::Buffer();
    rtc::ByteBufferWriter out;
    out.WriteUInt8(PacketType::tPing);
    out.WriteUInt32(msg->id);
    return rtc::Buffer(out.Data(), out.Length());
}

std::unique_ptr<message::Base> Protocol10::PingDecode(const uint8_t *buffer, size_t size) {
    rtc::ByteBufferReader in(reinterpret_cast<const char *>(buffer), size);
    auto msg = std::make_unique<message::Ping>();
    in.ReadUInt32(&msg->id);
    return msg;
}

rtc::Buffer Protocol10::PongEncode(const message::Base *msg_base) {
    const auto *msg = dynamic_cast<const message::Pong *>(msg_base);
    if (!msg)
        return rtc::Buffer();
    rtc::ByteBufferWriter out;
    out.WriteUInt8(PacketType::tPong);
    out.WriteUInt32(msg->id);
    return rtc::Buffer(out.Data(), out.Length());
}

std::unique_ptr<message::Base> Protocol10::PongDecode(const uint8_t *buffer, size_t size) {
    rtc::ByteBufferReader in(reinterpret_cast<const char *>(buffer), size);
    auto msg = std::make_unique<message::Pong>();
    in.ReadUInt32(&msg->id);
    return msg;
}
