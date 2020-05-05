#ifndef DEMO_LAYER92_H
#define DEMO_LAYER92_H


#include "LayerBase.h"
#include "Message.h"
#include "Protocol10.h"

#include "rtc_base/byte_buffer.h"

#include <cstdint>
#include <cstddef>

struct CryptoFunctions {
    void (*rand_bytes)(uint8_t* buffer, size_t length);
    void (*sha1)(uint8_t* msg, size_t length, uint8_t* output);
    void (*sha256)(uint8_t* msg, size_t length, uint8_t* output);
    void (*aes_ige_encrypt)(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv);
    void (*aes_ige_decrypt)(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv);
    void (*aes_ctr_encrypt)(uint8_t* inout, size_t length, uint8_t* key, uint8_t* iv, uint8_t* ecount, uint32_t* num);
    void (*aes_cbc_encrypt)(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv);
    void (*aes_cbc_decrypt)(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv);
};

typedef unsigned char EncryptionKey[256];

class Layer92 : public LayerBase {
public:
    static CryptoFunctions crypto;

    explicit Layer92(const EncryptionKey& encryptionKey, bool isOutgoing);
    void EncryptForTCPO2(unsigned char *buffer, size_t len, TCPO2State *state) override;
    void GenerateTCPO2States(unsigned char *buffer, TCPO2State *recvState, TCPO2State *sendState) override;
    std::unique_ptr<message::Base> DecodePacket(rtc::ByteBufferReader& in) override;
    rtc::Buffer EncodePacket(const message::Base *msg_base) override;

private:
    void KDF2(unsigned char* msgKey, size_t x, unsigned char *aesKey, unsigned char *aesIv);
    std::unique_ptr<message::Base> DecodeRelayPacket(rtc::ByteBufferReader& in);
    std::unique_ptr<message::Base> DecodeProtocolPacket(rtc::ByteBufferReader& in);
    rtc::Buffer EncodeRelayPacket(const message::Base *msg_base);
    rtc::Buffer EncodeProtocolPacket(const message::Base *msg_base);

    EncryptionKey encryptionKey;
    bool isOutgoing;
};


#endif //DEMO_LAYER92_H
