#import <XCTest/XCTest.h>

#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTEncryption.h>
#import <MtProtoKit/MTMessageEncryptionKey.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>

static NSData *randomData(NSUInteger length) {
    NSMutableData *data = [[NSMutableData alloc] initWithLength:length];
    if (length != 0) {
        arc4random_buf(data.mutableBytes, length);
    }
    return data;
}

static MTDatacenterAuthKey *randomAuthKey(void) {
    int64_t authKeyId = 0;
    arc4random_buf(&authKeyId, 8);
    return [[MTDatacenterAuthKey alloc] initWithAuthKey:randomData(256) authKeyId:authKeyId validUntilTimestamp:INT32_MAX notBound:false];
}

// The server's half of MTProto 2.0: x = 8, msg_key from auth_key[96..128], key/iv
// derived with toClient = true. Produces auth_key_id ‖ msg_key ‖ AES-IGE(plaintext).
static NSData *serverFrame(NSData *paddedPlaintext, MTDatacenterAuthKey *authKey) {
    NSMutableData *toHash = [[NSMutableData alloc] init];
    [toHash appendBytes:((uint8_t *)authKey.authKey.bytes) + 96 length:32];
    [toHash appendData:paddedPlaintext];
    NSData *messageKey = [MTSha256(toHash) subdataWithRange:NSMakeRange(8, 16)];

    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:authKey.authKey messageKey:messageKey toClient:true];
    NSData *encrypted = MTAesEncrypt(paddedPlaintext, encryptionKey.key, encryptionKey.iv);

    NSMutableData *frame = [[NSMutableData alloc] init];
    int64_t authKeyId = authKey.authKeyId;
    [frame appendBytes:&authKeyId length:8];
    [frame appendData:messageKey];
    [frame appendData:encrypted];
    return frame;
}

// Byte-for-byte reference of the decrypt path before the single-allocation
// rewrite: slice, decrypt into a fresh buffer, concatenate to hash, compare.
// It keeps the old padding formula (which forgot to subtract the 32-byte header),
// so it agrees with the new code for ordinary frames but not at the edges; see
// testPaddingBoundsAreAppliedAfterTheHeader for the corrected behaviour.
static NSData *referenceDecrypt(NSData *transportData, MTDatacenterAuthKey *authKey) {
    if (transportData.length < 24 + 36) {
        return nil;
    }
    int64_t authKeyId = 0;
    [transportData getBytes:&authKeyId range:NSMakeRange(0, 8)];
    if (authKeyId != authKey.authKeyId) {
        return nil;
    }
    NSData *embeddedMessageKey = [transportData subdataWithRange:NSMakeRange(8, 16)];
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:authKey.authKey messageKey:embeddedMessageKey toClient:true];
    if (encryptionKey == nil) {
        return nil;
    }
    NSData *dataToDecrypt = [transportData subdataWithRange:NSMakeRange(24, ((int32_t)(transportData.length - 24)) & (~15))];
    NSData *decryptedData = MTAesDecrypt(dataToDecrypt, encryptionKey.key, encryptionKey.iv);

    NSMutableData *msgKeyLargeData = [[NSMutableData alloc] init];
    [msgKeyLargeData appendBytes:((uint8_t *)authKey.authKey.bytes) + 96 length:32];
    [msgKeyLargeData appendData:decryptedData];
    NSData *messageKey = [MTSha256(msgKeyLargeData) subdataWithRange:NSMakeRange(8, 16)];
    if (![messageKey isEqualToData:embeddedMessageKey]) {
        return nil;
    }

    int32_t messageDataLength = 0;
    [decryptedData getBytes:&messageDataLength range:NSMakeRange(28, 4)];
    int32_t paddingLength = ((int32_t)decryptedData.length) - messageDataLength;
    if (paddingLength < 12 || paddingLength > 1024) {
        return nil;
    }
    if (messageDataLength < 0 || messageDataLength > (int32_t)decryptedData.length) {
        return nil;
    }
    return decryptedData;
}

@interface MTProtoIncomingDecryptTests : XCTestCase
@end

@implementation MTProtoIncomingDecryptTests

- (void)testDecryptMatchesReferenceImplementation {
    NSUInteger bodyLengths[] = { 0, 4, 100, 1024, 4096, 512 * 1024 };
    for (NSUInteger i = 0; i < sizeof(bodyLengths) / sizeof(bodyLengths[0]); i++) {
        for (int iteration = 0; iteration < 4; iteration++) {
            MTDatacenterAuthKey *authKey = randomAuthKey();
            NSData *plaintext = [MTProto _paddedPlaintextWithSalt:1 sessionId:2 messageId:3 seqNo:4 body:randomData(bodyLengths[i]) extendedPadding:iteration % 2 == 0];
            NSData *frame = serverFrame(plaintext, authKey);

            NSData *reference = referenceDecrypt(frame, authKey);
            NSData *actual = [MTProto _decryptedPayloadForIncomingTransportData:frame authKey:authKey];

            XCTAssertNotNil(reference);
            XCTAssertEqualObjects(actual, reference, @"body length %lu", (unsigned long)bodyLengths[i]);
            XCTAssertEqualObjects(actual, plaintext);
        }
    }
}

- (void)testTrailingPartialBlockIsIgnoredLikeBefore {
    MTDatacenterAuthKey *authKey = randomAuthKey();
    NSData *plaintext = [MTProto _paddedPlaintextWithSalt:1 sessionId:2 messageId:3 seqNo:4 body:randomData(200) extendedPadding:false];
    NSMutableData *frame = [serverFrame(plaintext, authKey) mutableCopy];
    [frame appendData:randomData(5)];

    XCTAssertEqualObjects([MTProto _decryptedPayloadForIncomingTransportData:frame authKey:authKey], referenceDecrypt(frame, authKey));
    XCTAssertEqualObjects([MTProto _decryptedPayloadForIncomingTransportData:frame authKey:authKey], plaintext);
}

- (void)testTamperedFramesAreRejected {
    MTDatacenterAuthKey *authKey = randomAuthKey();
    NSData *plaintext = [MTProto _paddedPlaintextWithSalt:1 sessionId:2 messageId:3 seqNo:4 body:randomData(300) extendedPadding:false];
    NSData *frame = serverFrame(plaintext, authKey);
    XCTAssertNotNil([MTProto _decryptedPayloadForIncomingTransportData:frame authKey:authKey]);

    // Flipped ciphertext byte → msg_key mismatch.
    NSMutableData *flipped = [frame mutableCopy];
    ((uint8_t *)flipped.mutableBytes)[24 + 40] ^= 0x01;
    XCTAssertNil([MTProto _decryptedPayloadForIncomingTransportData:flipped authKey:authKey]);

    // Flipped msg_key byte.
    NSMutableData *badKey = [frame mutableCopy];
    ((uint8_t *)badKey.mutableBytes)[8] ^= 0x01;
    XCTAssertNil([MTProto _decryptedPayloadForIncomingTransportData:badKey authKey:authKey]);

    // Wrong auth_key_id.
    NSMutableData *badId = [frame mutableCopy];
    ((uint8_t *)badId.mutableBytes)[0] ^= 0x01;
    XCTAssertNil([MTProto _decryptedPayloadForIncomingTransportData:badId authKey:authKey]);

    // Truncated below the minimum frame.
    XCTAssertNil([MTProto _decryptedPayloadForIncomingTransportData:[frame subdataWithRange:NSMakeRange(0, 59)] authKey:authKey]);

    // A different key.
    XCTAssertNil([MTProto _decryptedPayloadForIncomingTransportData:frame authKey:randomAuthKey()]);

    // A key too short to hold the fragments the protocol reads.
    MTDatacenterAuthKey *shortKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:randomData(64) authKeyId:authKey.authKeyId validUntilTimestamp:INT32_MAX notBound:false];
    XCTAssertNil([MTProto _decryptedPayloadForIncomingTransportData:frame authKey:shortKey]);
}

- (void)testInconsistentLengthFieldsAreRejected {
    MTDatacenterAuthKey *authKey = randomAuthKey();

    // Padding above 1024 bytes: header + 16-byte body + 1040 padding.
    NSMutableData *tooMuchPadding = [[NSMutableData alloc] init];
    int64_t zero64 = 0;
    int32_t zero32 = 0;
    int32_t bodyLength = 16;
    [tooMuchPadding appendBytes:&zero64 length:8];
    [tooMuchPadding appendBytes:&zero64 length:8];
    [tooMuchPadding appendBytes:&zero64 length:8];
    [tooMuchPadding appendBytes:&zero32 length:4];
    [tooMuchPadding appendBytes:&bodyLength length:4];
    [tooMuchPadding appendData:randomData(16 + 1040)];
    XCTAssertEqual(tooMuchPadding.length % 16, (NSUInteger)0);
    XCTAssertNil([MTProto _decryptedPayloadForIncomingTransportData:serverFrame(tooMuchPadding, authKey) authKey:authKey]);
    XCTAssertNil(referenceDecrypt(serverFrame(tooMuchPadding, authKey), authKey));

    // Declared body longer than the whole payload.
    NSMutableData *overlong = [[NSMutableData alloc] init];
    int32_t hugeLength = 1 << 20;
    [overlong appendBytes:&zero64 length:8];
    [overlong appendBytes:&zero64 length:8];
    [overlong appendBytes:&zero64 length:8];
    [overlong appendBytes:&zero32 length:4];
    [overlong appendBytes:&hugeLength length:4];
    [overlong appendData:randomData(32)];
    XCTAssertNil([MTProto _decryptedPayloadForIncomingTransportData:serverFrame(overlong, authKey) authKey:authKey]);
}

// Builds a payload by hand: 32-byte header with the given message_data_length,
// then `bodyLength + paddingLength` random bytes.
static NSData *payloadWithBodyLength(int32_t bodyLength, NSUInteger paddingLength) {
    NSMutableData *payload = [[NSMutableData alloc] init];
    int64_t zero64 = 0;
    int32_t zero32 = 0;
    [payload appendBytes:&zero64 length:8];
    [payload appendBytes:&zero64 length:8];
    [payload appendBytes:&zero64 length:8];
    [payload appendBytes:&zero32 length:4];
    [payload appendBytes:&bodyLength length:4];
    [payload appendData:randomData((NSUInteger)bodyLength + paddingLength)];
    return payload;
}

- (void)testPaddingBoundsAreAppliedAfterTheHeader {
    MTDatacenterAuthKey *authKey = randomAuthKey();

    // 1000 bytes of padding is spec-legal (12..1024). The old formula counted the
    // 32-byte header as padding and rejected anything above 992.
    NSData *largePadding = payloadWithBodyLength(24, 1000);
    XCTAssertEqual(largePadding.length % 16, (NSUInteger)0);
    XCTAssertNotNil([MTProto _decryptedPayloadForIncomingTransportData:serverFrame(largePadding, authKey) authKey:authKey]);
    XCTAssertNil(referenceDecrypt(serverFrame(largePadding, authKey), authKey), @"documents the old off-by-32 rejection");

    // 1024 is the last legal value; 1040 is over.
    XCTAssertNotNil([MTProto _decryptedPayloadForIncomingTransportData:serverFrame(payloadWithBodyLength(16, 1024), authKey) authKey:authKey]);
    XCTAssertNil([MTProto _decryptedPayloadForIncomingTransportData:serverFrame(payloadWithBodyLength(16, 1040), authKey) authKey:authKey]);

    // 8 bytes of padding is below the 12-byte minimum. The old formula saw 8 + 32
    // and let it through.
    NSData *tinyPadding = payloadWithBodyLength(24, 8);
    XCTAssertEqual(tinyPadding.length % 16, (NSUInteger)0);
    XCTAssertNil([MTProto _decryptedPayloadForIncomingTransportData:serverFrame(tinyPadding, authKey) authKey:authKey]);
    XCTAssertNotNil(referenceDecrypt(serverFrame(tinyPadding, authKey), authKey), @"documents the old off-by-32 acceptance");

    // Exactly 12 bytes is the minimum and passes.
    XCTAssertNotNil([MTProto _decryptedPayloadForIncomingTransportData:serverFrame(payloadWithBodyLength(20, 12), authKey) authKey:authKey]);

    // A body that fills everything after the header leaves no room for padding.
    XCTAssertNil([MTProto _decryptedPayloadForIncomingTransportData:serverFrame(payloadWithBodyLength(64, 0), authKey) authKey:authKey]);
}

- (void)testUnalignedInputIsHandledByTheRawAesHelpers {
    MTDatacenterAuthKey *authKey = randomAuthKey();
    NSData *plaintext = [MTProto _paddedPlaintextWithSalt:1 sessionId:2 messageId:3 seqNo:4 body:randomData(150) extendedPadding:false];
    NSData *frame = serverFrame(plaintext, authKey);

    // Wrap the bytes at an odd offset inside a larger allocation so the NSData's
    // bytes pointer is guaranteed misaligned; both directions must still work.
    uint8_t *frameStorage = malloc(frame.length + 3);
    memcpy(frameStorage + 3, frame.bytes, frame.length);
    NSData *oddFrame = [NSData dataWithBytesNoCopy:frameStorage + 3 length:frame.length freeWhenDone:NO];
    XCTAssertNotEqual(((uintptr_t)oddFrame.bytes) % sizeof(long), (uintptr_t)0);
    XCTAssertEqualObjects([MTProto _decryptedPayloadForIncomingTransportData:oddFrame authKey:authKey], plaintext);
    free(frameStorage);

    uint8_t *plainStorage = malloc(plaintext.length + 1);
    memcpy(plainStorage + 1, plaintext.bytes, plaintext.length);
    NSData *oddPlaintext = [NSData dataWithBytesNoCopy:plainStorage + 1 length:plaintext.length freeWhenDone:NO];
    XCTAssertNotEqual(((uintptr_t)oddPlaintext.bytes) % sizeof(long), (uintptr_t)0);
    XCTAssertEqualObjects([MTProto _encryptedTransportDataForPaddedPlaintext:oddPlaintext authKey:authKey quickAckId:NULL],
                          [MTProto _encryptedTransportDataForPaddedPlaintext:plaintext authKey:authKey quickAckId:NULL]);
    free(plainStorage);
}

- (void)testReadIncomingPayloadAuthorizedLayout {
    NSData *body = randomData(77);
    NSData *payload = [MTProto _paddedPlaintextWithSalt:0x1111 sessionId:0x2222 messageId:0x3333 seqNo:0x44 body:body extendedPadding:false];

    int64_t salt = 0, sessionId = 0, messageId = 0;
    int32_t seqNo = 0, topMessageSize = -1;
    NSData *readBody = nil;
    XCTAssertTrue([MTProto _readIncomingPayload:payload unauthorized:false salt:&salt sessionId:&sessionId messageId:&messageId seqNo:&seqNo topMessageSize:&topMessageSize body:&readBody]);
    XCTAssertEqual(salt, (int64_t)0x1111);
    XCTAssertEqual(sessionId, (int64_t)0x2222);
    XCTAssertEqual(messageId, (int64_t)0x3333);
    XCTAssertEqual(seqNo, (int32_t)0x44);
    XCTAssertEqual(topMessageSize, (int32_t)0);
    // The body is everything after the 32-byte header, padding included (as before).
    XCTAssertEqualObjects(readBody, [payload subdataWithRange:NSMakeRange(32, payload.length - 32)]);
    XCTAssertEqualObjects([readBody subdataWithRange:NSMakeRange(0, body.length)], body);

    XCTAssertFalse([MTProto _readIncomingPayload:[payload subdataWithRange:NSMakeRange(0, 31)] unauthorized:false salt:&salt sessionId:&sessionId messageId:&messageId seqNo:&seqNo topMessageSize:&topMessageSize body:&readBody]);
}

- (void)testReadIncomingPayloadUnauthorizedLayout {
    NSMutableData *payload = [[NSMutableData alloc] init];
    int64_t authKeyId = 0;
    int64_t messageIdIn = 0x5555;
    int32_t size = 24;
    NSData *body = randomData(24);
    [payload appendBytes:&authKeyId length:8];
    [payload appendBytes:&messageIdIn length:8];
    [payload appendBytes:&size length:4];
    [payload appendData:body];

    int64_t salt = 9, sessionId = 9, messageId = 0;
    int32_t seqNo = 9, topMessageSize = 0;
    NSData *readBody = nil;
    XCTAssertTrue([MTProto _readIncomingPayload:payload unauthorized:true salt:&salt sessionId:&sessionId messageId:&messageId seqNo:&seqNo topMessageSize:&topMessageSize body:&readBody]);
    XCTAssertEqual(messageId, messageIdIn);
    XCTAssertEqual(topMessageSize, (int32_t)24);
    XCTAssertEqual(salt, (int64_t)0);
    XCTAssertEqual(sessionId, (int64_t)0);
    XCTAssertEqual(seqNo, (int32_t)0);
    XCTAssertEqualObjects(readBody, body);

    // Non-zero auth_key_id is not a plaintext message.
    NSMutableData *encryptedLooking = [payload mutableCopy];
    ((uint8_t *)encryptedLooking.mutableBytes)[0] = 1;
    XCTAssertFalse([MTProto _readIncomingPayload:encryptedLooking unauthorized:true salt:&salt sessionId:&sessionId messageId:&messageId seqNo:&seqNo topMessageSize:&topMessageSize body:&readBody]);

    // Declared size below 4.
    NSMutableData *tinySize = [payload mutableCopy];
    int32_t three = 3;
    [tinySize replaceBytesInRange:NSMakeRange(16, 4) withBytes:&three];
    XCTAssertFalse([MTProto _readIncomingPayload:tinySize unauthorized:true salt:&salt sessionId:&sessionId messageId:&messageId seqNo:&seqNo topMessageSize:&topMessageSize body:&readBody]);

    // Truncated header.
    XCTAssertFalse([MTProto _readIncomingPayload:[payload subdataWithRange:NSMakeRange(0, 19)] unauthorized:true salt:&salt sessionId:&sessionId messageId:&messageId seqNo:&seqNo topMessageSize:&topMessageSize body:&readBody]);
}

- (void)testServerFrameRoundTripsToBody {
    MTDatacenterAuthKey *authKey = randomAuthKey();
    NSData *body = randomData(3000);
    NSData *plaintext = [MTProto _paddedPlaintextWithSalt:7 sessionId:8 messageId:9 seqNo:10 body:body extendedPadding:true];

    NSData *decrypted = [MTProto _decryptedPayloadForIncomingTransportData:serverFrame(plaintext, authKey) authKey:authKey];
    XCTAssertNotNil(decrypted);

    int64_t salt = 0, sessionId = 0, messageId = 0;
    int32_t seqNo = 0, topMessageSize = 0;
    NSData *readBody = nil;
    XCTAssertTrue([MTProto _readIncomingPayload:decrypted unauthorized:false salt:&salt sessionId:&sessionId messageId:&messageId seqNo:&seqNo topMessageSize:&topMessageSize body:&readBody]);
    XCTAssertEqual(salt, (int64_t)7);
    XCTAssertEqual(sessionId, (int64_t)8);
    XCTAssertEqual(messageId, (int64_t)9);
    XCTAssertEqual(seqNo, (int32_t)10);
    XCTAssertEqualObjects([readBody subdataWithRange:NSMakeRange(0, body.length)], body);
}

@end
