#include "Layer92.h"

#include "Message.h"

#include "rtc_base/byte_buffer.h"
#include "rtc_base/byte_order.h"

#include <cstring>
#include <algorithm>

namespace {

#define TLID_UDP_REFLECTOR_SELF_INFO 0xc01572c7
#define TLID_UDP_REFLECTOR_PEER_INFO 0x27D9371C

#ifdef _MSC_VER
#define MSC_STACK_FALLBACK(a, b) (b)
#else
#define MSC_STACK_FALLBACK(a, b) (a)
#endif

}

Layer92::Layer92(const EncryptionKey& encryptionKey_, bool isOutgoing)
: LayerBase(92)
, encryptionKey()
, isOutgoing(isOutgoing) {
    memcpy(encryptionKey, encryptionKey_, sizeof(encryptionKey));
}

void Layer92::EncryptForTCPO2(unsigned char *buffer, size_t len, TCPO2State *state) {
    crypto.aes_ctr_encrypt(buffer, len, state->key, state->iv, state->ecount, &state->num);
}

void Layer92::GenerateTCPO2States(unsigned char* buffer, TCPO2State* recvState, TCPO2State* sendState) {
    memset(recvState, 0, sizeof(TCPO2State));
    memset(sendState, 0, sizeof(TCPO2State));
    unsigned char nonce[64];
    uint32_t *first = reinterpret_cast<uint32_t *>(nonce), *second = first + 1;
    uint32_t first1 = 0x44414548U, first2 = 0x54534f50U, first3 = 0x20544547U, first4 = 0x20544547U, first5 = 0xeeeeeeeeU;
    uint32_t second1 = 0;
    do {
        crypto.rand_bytes(nonce, sizeof(nonce));
    } while (*first == first1 || *first == first2 || *first == first3 || *first == first4 || *first == first5 ||
             *second == second1 || *reinterpret_cast<unsigned char *>(nonce) == 0xef);

    // prepare encryption key/iv
    memcpy(sendState->key, nonce + 8, 32);
    memcpy(sendState->iv, nonce + 8 + 32, 16);

    // prepare decryption key/iv
    char reversed[48];
    memcpy(reversed, nonce + 8, sizeof(reversed));
    std::reverse(reversed, reversed + sizeof(reversed));
    memcpy(recvState->key, reversed, 32);
    memcpy(recvState->iv, reversed + 32, 16);

    // write protocol identifier
    *reinterpret_cast<uint32_t *>(nonce + 56) = 0xefefefefU;
    memcpy(buffer, nonce, 56);
    EncryptForTCPO2(nonce, sizeof(nonce), sendState);
    memcpy(buffer + 56, nonce + 56, 8);
}

std::unique_ptr<message::Base> Layer92::DecodeRelayPacket(rtc::ByteBufferReader& in) {
    if (in.Length() < 12 + 4 + 16)
        return nullptr;
    if (*reinterpret_cast<const uint64_t *>(in.Data()) != 0xFFFFFFFFFFFFFFFFLL)
        return nullptr;
    if (*reinterpret_cast<const uint32_t *>(in.Data() + 8) != 0xFFFFFFFF)
        return nullptr;

    // relay special request response
    in.Consume(12);
    uint32_t tlid;
    if (!in.ReadUInt32(&tlid))
        return nullptr;

    if (tlid == TLID_UDP_REFLECTOR_SELF_INFO) {
        if (in.Length() < 32)
            return nullptr;

        auto msg = std::make_unique<message::RelayPong>();
        in.ReadUInt32(&msg->date);
        in.ReadUInt64(&msg->query_id);
        in6_addr myIP{};
        in.ReadBytes(reinterpret_cast<char *>(&myIP), 16);
        uint32_t myPort;  // int32_t in src; why not uint16_t?
        in.ReadUInt32(&myPort);
        msg->my_addr = rtc::SocketAddress(rtc::IPAddress(myIP), myPort);
        return msg;
    }
    if (tlid == TLID_UDP_REFLECTOR_PEER_INFO) {
        if (in.Length() < 16)
            return nullptr;
        auto msg = std::make_unique<message::PeerInfo>();
        uint32_t myAddr;
        uint32_t myPort;
        uint32_t peerAddr;
        uint32_t peerPort;
        in.ReadUInt32(&myAddr);
        in.ReadUInt32(&myPort);
        in.ReadUInt32(&peerAddr);
        in.ReadUInt32(&peerPort);
        msg->my_addr = rtc::SocketAddress(myAddr, myPort);
        msg->peer_addr = rtc::SocketAddress(peerAddr, peerPort);
        return msg;
    }
    return nullptr;
}

void Layer92::KDF2(unsigned char *msgKey, size_t x, unsigned char *aesKey, unsigned char *aesIv) {
    uint8_t sA[32], sB[32];
    uint8_t buf[16 + 36];
    memcpy(buf, msgKey, 16);
    memcpy(buf + 16, encryptionKey + x, 36);
    crypto.sha256(buf, 16 + 36, sA);
    memcpy(buf, encryptionKey + 40 + x, 36);
    memcpy(buf + 36, msgKey, 16);
    crypto.sha256(buf, 36 + 16, sB);
    memcpy(aesKey, sA, 8);
    memcpy(aesKey + 8, sB + 8, 16);
    memcpy(aesKey + 8 + 16, sA + 24, 8);
    memcpy(aesIv, sB, 8);
    memcpy(aesIv + 8, sA + 8, 16);
    memcpy(aesIv + 8 + 16, sB + 24, 8);
}

std::unique_ptr<message::Base> Layer92::DecodeProtocolPacket(rtc::ByteBufferReader& in) {
    unsigned char msgKey[16];
    memcpy(msgKey, in.Data(), 16);

    unsigned char decrypted[1500];
    unsigned char aesKey[32], aesIv[32];
    KDF2(msgKey, isOutgoing ? 8 : 0, aesKey, aesIv);
    size_t decryptedLen = in.Length() - 16;
    if (decryptedLen > sizeof(decrypted))
        return nullptr;
    if (decryptedLen % 16 != 0)
        return nullptr;  // wrong decrypted length

    in.Consume(16);
    crypto.aes_ige_decrypt((uint8_t *)in.Data(), decrypted, decryptedLen, aesKey, aesIv);
    in.Consume(decryptedLen);

    rtc::ByteBufferWriter buf;
    size_t x = isOutgoing ? 8 : 0;
    buf.WriteBytes((char *)encryptionKey + 88 + x, 32);
    buf.WriteBytes((char *)decrypted, decryptedLen);
    unsigned char msgKeyLarge[32];
    crypto.sha256((uint8_t *)buf.Data(), buf.Length(), msgKeyLarge);
    if (memcmp(msgKey, msgKeyLarge + 8, 16) != 0)
        return nullptr;  // packet has wrong hash

    uint16_t innerLen;
    memcpy(&innerLen, decrypted, 2);
    if (innerLen > decryptedLen)
        return nullptr;  // packet has wrong inner length
//    if (decryptedLen - innerLen < 16)
//        return nullptr;  // packet has too little padding
    return protocol->ReadProtocolPacket(decrypted + 2, innerLen);
}

std::unique_ptr<message::Base> Layer92::DecodePacket(rtc::ByteBufferReader& in) {
    auto msg = DecodeRelayPacket(in);
    if (msg)
        return msg;
    return DecodeProtocolPacket(in);
}

rtc::Buffer Layer92::EncodePacket(const message::Base *msg_base) {
    auto buf = EncodeRelayPacket(msg_base);
    if (!buf.empty())
        return buf;
    return EncodeProtocolPacket(msg_base);
}

rtc::Buffer Layer92::EncodeRelayPacket(const message::Base *msg_base) {
    if (msg_base->ID == message::tRelayPing) {
        const auto *msg = dynamic_cast<const message::RelayPing *>(msg_base);
        if (!msg)
            return rtc::Buffer();
        unsigned char buf[16];
        memset(buf, 0xFF, 16);
        return rtc::Buffer(buf, 16);
    }
    if (msg_base->ID == message::tGetPeerInfo) {
        const auto *msg = dynamic_cast<const message::GetPeerInfo *>(msg_base);
        if (!msg)
            return rtc::Buffer();
        rtc::ByteBufferWriter out;
        out.WriteUInt32(-1);
        out.WriteUInt32(-1);
        out.WriteUInt32(-1);
        out.WriteUInt32(-1);
        int64_t id;
        crypto.rand_bytes(reinterpret_cast<uint8_t*>(&id), 8);
        out.WriteUInt64(id);
        return rtc::Buffer(out.Data(), out.Length());
    }
    return rtc::Buffer();
}

rtc::Buffer Layer92::EncodeProtocolPacket(const message::Base *msg_base) {
    rtc::Buffer internal = protocol->WriteProtocolPacket(msg_base);
    if (internal.empty())
        return rtc::Buffer();

    rtc::ByteBufferWriter out;
    rtc::ByteBufferWriter inner;
    uint16_t len = internal.size();
    inner.WriteBytes((char *)&len, 2);  // for backward compatibility
    inner.WriteBytes((char *)internal.data(), internal.size());

    size_t padLen = 16 - inner.Length() % 16;
//    if (padLen < 16)
//        padLen += 16;
    uint8_t padding[32];
    crypto.rand_bytes(padding, padLen);
    inner.WriteBytes((char *)padding, padLen);
    assert(inner.Length() % 16 == 0);

    unsigned char key[32], iv[32], msgKey[16];
    rtc::ByteBufferWriter buf;
    size_t x = isOutgoing ? 0 : 8;
    buf.WriteBytes((char *)encryptionKey + 88 + x, 32);
    buf.WriteBytes(inner.Data(), inner.Length());
    unsigned char msgKeyLarge[32];
    crypto.sha256((uint8_t *)buf.Data(), buf.Length(), msgKeyLarge);
    memcpy(msgKey, msgKeyLarge + 8, 16);
    KDF2(msgKey, isOutgoing ? 0 : 8, key, iv);
    out.WriteBytes((char *)msgKey, 16);

    unsigned char aesOut[MSC_STACK_FALLBACK(inner.Length(), 1500)];
    crypto.aes_ige_encrypt((uint8_t *)inner.Data(), aesOut, inner.Length(), key, iv);
    out.WriteBytes((char *)aesOut, inner.Length());
    return rtc::Buffer(out.Data(), out.Length());
}
