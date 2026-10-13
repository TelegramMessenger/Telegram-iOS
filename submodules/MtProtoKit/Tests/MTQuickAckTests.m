#import <XCTest/XCTest.h>

#import <MtProtoKit/MTQuickAck.h>
#import <MtProtoKit/MTEncryption.h>
#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>

// The server's side of the protocol, written out from the transport spec and TDLib
// (Transport::calc_message_key2 and IntermediateTransport::read_from_stream): the
// token is the little-endian first word of msg_key_large with bit 31 set, sent raw on
// intermediate framing and byte-swapped on abridged framing.
static uint32_t serverToken(const uint8_t *msgKeyLarge) {
    uint32_t word = 0;
    memcpy(&word, msgKeyLarge, 4);
    return word | 0x80000000u;
}

static void serverIntermediateWire(const uint8_t *msgKeyLarge, uint8_t out[4]) {
    uint32_t token = serverToken(msgKeyLarge);
    memcpy(out, &token, 4);
}

static void serverAbridgedWire(const uint8_t *msgKeyLarge, uint8_t out[4]) {
    uint8_t raw[4];
    serverIntermediateWire(msgKeyLarge, raw);
    out[0] = raw[3];
    out[1] = raw[2];
    out[2] = raw[1];
    out[3] = raw[0];
}

@interface MTQuickAckTests : XCTestCase
@end

@implementation MTQuickAckTests

- (void)testClientTokenIsFirstWordWithoutFlagBit {
    uint8_t msgKeyLarge[32] = { 0x12, 0x34, 0x56, 0xF8 };
    XCTAssertEqual(MTQuickAckTokenFromMsgKeyLarge(msgKeyLarge), (int32_t)0x78563412);

    uint8_t noHighBit[32] = { 0xAA, 0xBB, 0xCC, 0x0D };
    XCTAssertEqual(MTQuickAckTokenFromMsgKeyLarge(noHighBit), (int32_t)0x0DCCBBAA);
}

- (void)testIntermediateWireDecodesToClientToken {
    for (int i = 0; i < 256; i++) {
        uint8_t msgKeyLarge[32];
        arc4random_buf(msgKeyLarge, 32);

        uint8_t wire[4];
        serverIntermediateWire(msgKeyLarge, wire);
        int32_t word = 0;
        memcpy(&word, wire, 4);

        XCTAssertTrue((word & 0x80000000) == 0x80000000, @"flag bit must be set on the wire");
        XCTAssertEqual(MTQuickAckTokenFromIntermediateWord(word), MTQuickAckTokenFromMsgKeyLarge(msgKeyLarge));
    }
}

- (void)testAbridgedWireDecodesToClientToken {
    for (int i = 0; i < 256; i++) {
        uint8_t msgKeyLarge[32];
        arc4random_buf(msgKeyLarge, 32);

        uint8_t wire[4];
        serverAbridgedWire(msgKeyLarge, wire);

        XCTAssertTrue((wire[0] & 0x80) == 0x80, @"abridged flag must be in the first wire byte");
        XCTAssertEqual(MTQuickAckTokenFromAbridgedBytes(wire), MTQuickAckTokenFromMsgKeyLarge(msgKeyLarge));
    }
}

- (void)testDecodedTokenNeverHasFlagBit {
    for (int i = 0; i < 64; i++) {
        uint8_t msgKeyLarge[32];
        arc4random_buf(msgKeyLarge, 32);
        uint8_t wire[4];
        serverAbridgedWire(msgKeyLarge, wire);
        int32_t word = 0;
        memcpy(&word, wire, 4);
        XCTAssertTrue(MTQuickAckTokenFromMsgKeyLarge(msgKeyLarge) >= 0);
        XCTAssertTrue(MTQuickAckTokenFromAbridgedBytes(wire) >= 0);
        XCTAssertTrue(MTQuickAckTokenFromIntermediateWord(word) >= 0);
    }
}

- (void)testEncryptedFrameReportsTokenMatchingItsMsgKeyLarge {
    NSMutableData *keyData = [[NSMutableData alloc] initWithLength:256];
    arc4random_buf(keyData.mutableBytes, 256);
    MTDatacenterAuthKey *authKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:keyData authKeyId:42 validUntilTimestamp:INT32_MAX notBound:false];

    NSMutableData *plaintext = [[NSMutableData alloc] initWithLength:160];
    arc4random_buf(plaintext.mutableBytes, 160);

    int32_t token = -1;
    NSData *frame = [MTProto _encryptedTransportDataForPaddedPlaintext:plaintext authKey:authKey quickAckId:&token];
    XCTAssertNotNil(frame);

    // Recompute msg_key_large the way the server does and check both wire encodings
    // decode to the token the client recorded for this frame.
    NSMutableData *toHash = [[NSMutableData alloc] init];
    [toHash appendBytes:((uint8_t *)keyData.bytes) + 88 length:32];
    [toHash appendData:plaintext];
    NSData *msgKeyLarge = MTSha256(toHash);

    uint8_t intermediate[4], abridged[4];
    serverIntermediateWire(msgKeyLarge.bytes, intermediate);
    serverAbridgedWire(msgKeyLarge.bytes, abridged);
    int32_t intermediateWord = 0;
    memcpy(&intermediateWord, intermediate, 4);

    XCTAssertEqual(token, MTQuickAckTokenFromIntermediateWord(intermediateWord));
    XCTAssertEqual(token, MTQuickAckTokenFromAbridgedBytes(abridged));
}

@end
