#ifndef DEMO_LAYERBASE_H
#define DEMO_LAYERBASE_H


#include "ProtocolBase.h"

#include "rtc_base/buffer.h"
#include "rtc_base/byte_buffer.h"

#include <map>
#include <memory>

struct TCPO2State {
    unsigned char key[32];
    unsigned char iv[16];
    unsigned char ecount[16];
    uint32_t num;
};

class LayerBase {
public:
    bool ChangeProtocol(uint32_t protocol_version);

    virtual ~LayerBase() = default;
    virtual void EncryptForTCPO2(unsigned char *buffer, size_t len, TCPO2State *state) = 0;
    virtual void GenerateTCPO2States(unsigned char* buffer, TCPO2State* recvState, TCPO2State* sendState) = 0;
    virtual std::unique_ptr<message::Base> DecodePacket(rtc::ByteBufferReader& in) = 0;
    virtual rtc::Buffer EncodePacket(const message::Base *msg_base) = 0;

    const uint32_t version;

protected:
    explicit LayerBase(uint32_t version);

    std::unique_ptr<ProtocolBase> protocol;
};

#endif //DEMO_LAYERBASE_H
