#ifndef DEMO_PROTOCOL10_H
#define DEMO_PROTOCOL10_H


#include "Message.h"
#include "ProtocolBase.h"

#include <memory>

class Protocol10 : public ProtocolBase {
public:
    enum PacketType {
        tInit = 1,
        tInitAck,
        tRtpStream,
        tPing,
        tPong,
    };

    Protocol10();
    std::unique_ptr<message::Base> ReadProtocolPacket(const uint8_t *buffer, size_t size) override;
    rtc::Buffer WriteProtocolPacket(const message::Base *msg) override;

private:
    typedef std::function<std::unique_ptr<message::Base>(const uint8_t *, size_t)> Deserializer;
    typedef std::function<rtc::Buffer(const message::Base *)> Serializer;

    static const std::map<uint8_t, Deserializer> decoders;
    static const std::map<uint8_t, Serializer> encoders;

    static rtc::Buffer InitEncode(const message::Base *msg_base);
    static std::unique_ptr<message::Base> InitDecode(const uint8_t *buffer, size_t size);
    static rtc::Buffer InitAckEncode(const message::Base *msg_base);
    static std::unique_ptr<message::Base> InitAckDecode(const uint8_t *buffer, size_t size);
    static rtc::Buffer RtpStreamEncode(const message::Base *msg_base);
    static std::unique_ptr<message::Base> RtpStreamDecode(const uint8_t *buffer, size_t size);
    static rtc::Buffer PingEncode(const message::Base *msg_base);
    static std::unique_ptr<message::Base> PingDecode(const uint8_t *buffer, size_t size);
    static rtc::Buffer PongEncode(const message::Base *msg_base);
    static std::unique_ptr<message::Base> PongDecode(const uint8_t *buffer, size_t size);
};


#endif //DEMO_PROTOCOL10_H
