#import <MtProtoKit/MTQuickAck.h>

#import <libkern/OSByteOrder.h>

static const uint32_t MTQuickAckFlagBit = 0x80000000u;

int32_t MTQuickAckTokenFromMsgKeyLarge(const uint8_t *msgKeyLarge) {
    uint32_t token = 0;
    memcpy(&token, msgKeyLarge, 4);
    return (int32_t)(token & ~MTQuickAckFlagBit);
}

int32_t MTQuickAckTokenFromIntermediateWord(int32_t word) {
    return (int32_t)(((uint32_t)word) & ~MTQuickAckFlagBit);
}

int32_t MTQuickAckTokenFromAbridgedBytes(const uint8_t *bytes) {
    uint32_t swapped = 0;
    memcpy(&swapped, bytes, 4);
    return (int32_t)(OSSwapInt32(swapped) & ~MTQuickAckFlagBit);
}
