#ifndef DEMO_PROTOCOLBASE_H
#define DEMO_PROTOCOLBASE_H


#include "Message.h"

#include <map>
#include <memory>
#include <functional>

class ProtocolBase {
public:
    static const uint32_t actual_version;
    static const uint32_t minimal_version;
    static std::unique_ptr<ProtocolBase> CreateProtocol(uint32_t version);
    static bool IsSupported(uint32_t version);

    virtual ~ProtocolBase() = default;
    virtual std::unique_ptr<message::Base> ReadProtocolPacket(const uint8_t *buffer, size_t size) = 0;
    virtual rtc::Buffer WriteProtocolPacket(const message::Base *msg) = 0;

    const uint32_t version;

protected:
    explicit ProtocolBase(uint32_t version);

private:
    typedef std::function<std::unique_ptr<ProtocolBase>()> Constructor;
    static const std::map<uint8_t, Constructor> constructors;
};


#endif //DEMO_PROTOCOLBASE_H
