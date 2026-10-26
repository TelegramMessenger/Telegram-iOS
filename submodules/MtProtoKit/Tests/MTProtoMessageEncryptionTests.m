#import <XCTest/XCTest.h>

#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTEncryption.h>
#import <MtProtoKit/MTMessageEncryptionKey.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>

// Byte-for-byte reference of the encrypt path as it was before the single-
// allocation rewrite (build a concatenation to hash, encrypt a copy in place,
// then insert auth_key_id and msg_key at the front). Any change to the new
// implementation must keep producing exactly these bytes.
static NSData *referenceEncrypt(NSData *decryptedData, MTDatacenterAuthKey *authKey, int32_t *quickAckId) {
    NSMutableData *msgKeyLargeData = [[NSMutableData alloc] init];
    [msgKeyLargeData appendBytes:((uint8_t *)authKey.authKey.bytes) + 88 length:32];
    [msgKeyLargeData appendData:decryptedData];

    NSData *msgKeyLarge = MTSha256(msgKeyLargeData);
    NSData *messageKey = [msgKeyLarge subdataWithRange:NSMakeRange(8, 16)];
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:authKey.authKey messageKey:messageKey toClient:false];

    int32_t nQuickAckId = *((int32_t *)(msgKeyLarge.bytes));
    if (quickAckId != NULL) {
        *quickAckId = nQuickAckId & 0x7fffffff;
    }

    if (encryptionKey == nil) {
        return nil;
    }

    NSMutableData *encryptedData = [[NSMutableData alloc] init];
    [encryptedData appendData:decryptedData];
    MTAesEncryptInplace(encryptedData, encryptionKey.key, encryptionKey.iv);

    int64_t authKeyId = authKey.authKeyId;
    [encryptedData replaceBytesInRange:NSMakeRange(0, 0) withBytes:&authKeyId length:8];
    [encryptedData replaceBytesInRange:NSMakeRange(8, 0) withBytes:messageKey.bytes length:messageKey.length];

    return encryptedData;
}

static NSData *randomData(NSUInteger length) {
    NSMutableData *data = [[NSMutableData alloc] initWithLength:length];
    if (length != 0) {
        arc4random_buf(data.mutableBytes, length);
    }
    return data;
}

static MTDatacenterAuthKey *randomAuthKey(void) {
    NSData *keyData = randomData(256);
    int64_t authKeyId = 0;
    arc4random_buf(&authKeyId, 8);
    return [[MTDatacenterAuthKey alloc] initWithAuthKey:keyData authKeyId:authKeyId validUntilTimestamp:INT32_MAX notBound:false];
}

@interface MTProtoMessageEncryptionTests : XCTestCase
@end

@implementation MTProtoMessageEncryptionTests

- (void)testEncryptedFrameMatchesReferenceImplementation {
    NSUInteger lengths[] = { 48, 64, 160, 1024, 4096, 512 * 1024 + 64 };
    for (NSUInteger i = 0; i < sizeof(lengths) / sizeof(lengths[0]); i++) {
        for (int iteration = 0; iteration < 8; iteration++) {
            MTDatacenterAuthKey *authKey = randomAuthKey();
            NSData *plaintext = randomData(lengths[i]);

            int32_t referenceQuickAck = 0;
            int32_t quickAck = 0;
            NSData *reference = referenceEncrypt(plaintext, authKey, &referenceQuickAck);
            NSData *actual = [MTProto _encryptedTransportDataForPaddedPlaintext:plaintext authKey:authKey quickAckId:&quickAck];

            XCTAssertNotNil(actual);
            XCTAssertEqual(actual.length, 24 + lengths[i]);
            XCTAssertEqualObjects(actual, reference, @"frame differs for plaintext length %lu", (unsigned long)lengths[i]);
            XCTAssertEqual(quickAck, referenceQuickAck);
            XCTAssertTrue(quickAck >= 0, @"quick ack must have the high bit cleared");
        }
    }
}

- (void)testEncryptedFrameDecryptsBackToPlaintext {
    MTDatacenterAuthKey *authKey = randomAuthKey();
    NSData *plaintext = randomData(2048);

    NSData *frame = [MTProto _encryptedTransportDataForPaddedPlaintext:plaintext authKey:authKey quickAckId:NULL];
    XCTAssertNotNil(frame);

    int64_t authKeyId = 0;
    [frame getBytes:&authKeyId range:NSMakeRange(0, 8)];
    XCTAssertEqual(authKeyId, authKey.authKeyId);

    NSData *messageKey = [frame subdataWithRange:NSMakeRange(8, 16)];
    MTMessageEncryptionKey *encryptionKey = [MTMessageEncryptionKey messageEncryptionKeyV2ForAuthKey:authKey.authKey messageKey:messageKey toClient:false];
    XCTAssertNotNil(encryptionKey);

    NSData *decrypted = MTAesDecrypt([frame subdataWithRange:NSMakeRange(24, frame.length - 24)], encryptionKey.key, encryptionKey.iv);
    XCTAssertEqualObjects(decrypted, plaintext);

    // msg_key must be bytes 8..24 of SHA256(auth_key[88..120] ‖ plaintext).
    NSMutableData *toHash = [[NSMutableData alloc] init];
    [toHash appendBytes:((uint8_t *)authKey.authKey.bytes) + 88 length:32];
    [toHash appendData:plaintext];
    XCTAssertEqualObjects(messageKey, [MTSha256(toHash) subdataWithRange:NSMakeRange(8, 16)]);
}

- (void)testEncryptReturnsNilForShortAuthKey {
    MTDatacenterAuthKey *authKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:randomData(64) authKeyId:1 validUntilTimestamp:INT32_MAX notBound:false];
    XCTAssertNil([MTProto _encryptedTransportDataForPaddedPlaintext:randomData(64) authKey:authKey quickAckId:NULL]);
}

- (void)testEncryptReturnsNilForUnalignedOrEmptyPlaintext {
    MTDatacenterAuthKey *authKey = randomAuthKey();
    XCTAssertNil([MTProto _encryptedTransportDataForPaddedPlaintext:randomData(0) authKey:authKey quickAckId:NULL]);
    XCTAssertNil([MTProto _encryptedTransportDataForPaddedPlaintext:randomData(63) authKey:authKey quickAckId:NULL]);
    XCTAssertNil([MTProto _encryptedTransportDataForPaddedPlaintext:randomData(65) authKey:authKey quickAckId:NULL]);
    XCTAssertNotNil([MTProto _encryptedTransportDataForPaddedPlaintext:randomData(64) authKey:authKey quickAckId:NULL]);
}

- (void)testPaddedPlaintextLayoutAndPaddingBounds {
    for (int extended = 0; extended <= 1; extended++) {
        uint32_t maxPadding = extended ? 256 : 72;
        NSUInteger largestPaddingSeen = 0;

        for (NSUInteger bodyLength = 0; bodyLength <= 200; bodyLength++) {
            for (int iteration = 0; iteration < 4; iteration++) {
                int64_t salt = 0, sessionId = 0, messageId = 0;
                int32_t seqNo = 0;
                arc4random_buf(&salt, 8);
                arc4random_buf(&sessionId, 8);
                arc4random_buf(&messageId, 8);
                arc4random_buf(&seqNo, 4);
                NSData *body = randomData(bodyLength);

                NSMutableData *plaintext = [MTProto _paddedPlaintextWithSalt:salt sessionId:sessionId messageId:messageId seqNo:seqNo body:body extendedPadding:extended != 0];

                XCTAssertEqual(plaintext.length % 16, (NSUInteger)0);
                XCTAssertTrue(plaintext.length >= 32 + bodyLength + 12);

                int64_t readSalt = 0, readSessionId = 0, readMessageId = 0;
                int32_t readSeqNo = 0, readLength = 0;
                [plaintext getBytes:&readSalt range:NSMakeRange(0, 8)];
                [plaintext getBytes:&readSessionId range:NSMakeRange(8, 8)];
                [plaintext getBytes:&readMessageId range:NSMakeRange(16, 8)];
                [plaintext getBytes:&readSeqNo range:NSMakeRange(24, 4)];
                [plaintext getBytes:&readLength range:NSMakeRange(28, 4)];
                XCTAssertEqual(readSalt, salt);
                XCTAssertEqual(readSessionId, sessionId);
                XCTAssertEqual(readMessageId, messageId);
                XCTAssertEqual(readSeqNo, seqNo);
                XCTAssertEqual(readLength, (int32_t)bodyLength);
                XCTAssertEqualObjects([plaintext subdataWithRange:NSMakeRange(32, bodyLength)], body);

                NSUInteger padding = plaintext.length - 32 - bodyLength;
                XCTAssertTrue(padding >= 12, @"padding %lu below minimum", (unsigned long)padding);
                XCTAssertTrue(padding <= maxPadding, @"padding %lu above %u", (unsigned long)padding, maxPadding);
                largestPaddingSeen = MAX(largestPaddingSeen, padding);
            }
        }

        // The extra padding is random; over 800 samples it must exceed the bare
        // 12..27 minimum at least once or the randomization is not being applied.
        XCTAssertTrue(largestPaddingSeen > 27, @"padding never exceeded the minimum (extended=%d)", extended);
    }
}

- (void)testPaddingBytesAreRandom {
    NSData *body = randomData(40);
    NSMutableSet *paddings = [[NSMutableSet alloc] init];
    for (int i = 0; i < 16; i++) {
        NSMutableData *plaintext = [MTProto _paddedPlaintextWithSalt:1 sessionId:2 messageId:3 seqNo:4 body:body extendedPadding:false];
        [paddings addObject:[plaintext subdataWithRange:NSMakeRange(72, 12)]];
    }
    XCTAssertTrue(paddings.count > 1, @"padding bytes repeated across messages");
}

@end
