#import <XCTest/XCTest.h>

#import <MtProtoKit/MTEncryption.h>

#import "MTAes.h"

static NSData *randomData(NSUInteger length) {
    NSMutableData *data = [[NSMutableData alloc] initWithLength:length];
    if (length != 0) {
        arc4random_buf(data.mutableBytes, length);
    }
    return data;
}

static bool isAllZero(NSData *data) {
    const uint8_t *bytes = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) {
        if (bytes[i] != 0) {
            return false;
        }
    }
    return true;
}

// The AES helpers used to assert() their CommonCrypto status, which release
// builds compile out. These tests drive real CommonCrypto failures (an
// unsupported key length, a length that is not a block multiple) and check
// that the failure is reported and that nothing plaintext-derived is left in
// the output.
@interface MTAesFailureTests : XCTestCase
@end

@implementation MTAesFailureTests

- (void)testIgeRoundTripStillWorks {
    NSData *key = randomData(32);
    NSData *iv = randomData(32);
    NSData *plaintext = randomData(160);

    NSData *encrypted = MTAesEncrypt(plaintext, key, iv);
    XCTAssertNotNil(encrypted);
    XCTAssertEqual(encrypted.length, plaintext.length);
    XCTAssertNotEqualObjects(encrypted, plaintext);
    XCTAssertEqualObjects(MTAesDecrypt(encrypted, key, iv), plaintext);
}

- (void)testIgeEncryptRejectsUnsupportedKeyLengthAndZeroesOutput {
    NSData *plaintext = randomData(64);
    NSMutableData *out = [randomData(64) mutableCopy];
    unsigned char iv[32];
    arc4random_buf(iv, 32);
    uint8_t key[7] = { 1, 2, 3, 4, 5, 6, 7 };

    XCTAssertFalse(MyAesIgeEncrypt(plaintext.bytes, 64, out.mutableBytes, key, 7, iv));
    XCTAssertTrue(isAllZero(out), @"a failed encrypt must not leave plaintext-derived bytes behind");
}

- (void)testIgeEncryptRejectsNonBlockMultipleLength {
    NSData *key = randomData(32);
    NSData *iv = randomData(32);
    XCTAssertNil(MTAesEncrypt(randomData(50), key, iv));

    NSMutableData *out = [randomData(50) mutableCopy];
    unsigned char rawIv[32];
    memcpy(rawIv, iv.bytes, 32);
    XCTAssertFalse(MyAesIgeEncrypt(randomData(50).bytes, 50, out.mutableBytes, key.bytes, 32, rawIv));
    XCTAssertTrue(isAllZero(out));
}

- (void)testIgeDecryptRejectsBadInputsAndZeroesOutput {
    NSData *key = randomData(32);
    NSData *iv = randomData(32);
    XCTAssertNil(MTAesDecrypt(randomData(50), key, iv));

    NSMutableData *out = [randomData(64) mutableCopy];
    unsigned char rawIv[32];
    memcpy(rawIv, iv.bytes, 32);
    uint8_t shortKey[5] = { 0 };
    XCTAssertFalse(MyAesIgeDecrypt(randomData(64).bytes, 64, out.mutableBytes, shortKey, 5, rawIv));
    XCTAssertTrue(isAllZero(out));
}

- (void)testIgeZeroLengthIsANoOp {
    NSData *key = randomData(32);
    NSData *iv = randomData(32);
    unsigned char rawIv[32];
    memcpy(rawIv, iv.bytes, 32);
    uint8_t dummy[16] = { 0 };
    XCTAssertTrue(MyAesIgeEncrypt(dummy, 0, dummy, key.bytes, 32, rawIv));
    XCTAssertTrue(MyAesIgeDecrypt(dummy, 0, dummy, key.bytes, 32, rawIv));
    XCTAssertEqual(memcmp(rawIv, iv.bytes, 32), 0, @"iv must be untouched");
}

- (void)testRawHelpersReportFailure {
    NSData *key = randomData(32);
    NSData *iv = randomData(32);
    NSData *plaintext = randomData(48);
    NSMutableData *out = [[NSMutableData alloc] initWithLength:48];

    XCTAssertTrue(MTAesEncryptRaw(plaintext.bytes, out.mutableBytes, 48, key.bytes, iv.bytes));
    NSMutableData *back = [[NSMutableData alloc] initWithLength:48];
    XCTAssertTrue(MTAesDecryptRaw(out.bytes, back.mutableBytes, 48, key.bytes, iv.bytes));
    XCTAssertEqualObjects(back, plaintext);

    NSMutableData *odd = [randomData(40) mutableCopy];
    XCTAssertFalse(MTAesEncryptRaw(plaintext.bytes, odd.mutableBytes, 40, key.bytes, iv.bytes));
    XCTAssertTrue(isAllZero(odd));
}

- (void)testInplaceHelpersWipeOnFailure {
    NSData *key = randomData(32);
    NSData *iv = randomData(32);

    NSMutableData *good = [randomData(32) mutableCopy];
    NSData *original = [good copy];
    XCTAssertTrue(MTAesEncryptInplace(good, key, iv));
    XCTAssertNotEqualObjects(good, original);

    NSMutableData *bad = [randomData(30) mutableCopy];
    XCTAssertFalse(MTAesEncryptInplace(bad, key, iv));
    XCTAssertTrue(isAllZero(bad), @"the plaintext must not survive in a buffer the caller treats as ciphertext");

    NSMutableData *badBytes = [randomData(30) mutableCopy];
    unsigned char rawIv[32];
    memcpy(rawIv, iv.bytes, 32);
    MTAesEncryptBytesInplaceAndModifyIv(badBytes.mutableBytes, 30, key, rawIv);
    XCTAssertTrue(isAllZero(badBytes));
    XCTAssertEqual(memcmp(rawIv, iv.bytes, 32), 0, @"iv must not advance on failure");
}

- (void)testCbcDecryptReportsFailure {
    NSData *key = randomData(32);
    NSMutableData *iv = [randomData(16) mutableCopy];
    NSMutableData *out = [randomData(32) mutableCopy];
    uint8_t shortKey[3] = { 0 };
    XCTAssertFalse(MyAesCbcDecrypt(randomData(32).bytes, 32, out.mutableBytes, shortKey, 3, iv.mutableBytes));
    XCTAssertTrue(isAllZero(out));

    XCTAssertTrue(MyAesCbcDecrypt(randomData(32).bytes, 32, out.mutableBytes, key.bytes, 32, iv.mutableBytes));
}

- (void)testCtrInitFailsClosed {
    NSData *iv = randomData(16);
    uint8_t shortKey[9] = { 0 };
    MTAesCtr *ctr = [[MTAesCtr alloc] initWithKey:shortKey keyLength:9 iv:iv.bytes decrypt:true];
    XCTAssertNil(ctr, @"a cipher that could not be created must not exist: its keystream would be all zeros");

    NSData *key = randomData(32);
    MTAesCtr *ok = [[MTAesCtr alloc] initWithKey:key.bytes keyLength:32 iv:iv.bytes decrypt:true];
    XCTAssertNotNil(ok);
    NSData *plaintext = randomData(100);
    NSMutableData *out = [[NSMutableData alloc] initWithLength:100];
    XCTAssertTrue([ok encryptIn:plaintext.bytes out:out.mutableBytes len:100]);
    XCTAssertNotEqualObjects(out, plaintext);
    XCTAssertEqualObjects(MTAesCtrDecrypt(out, key, iv), plaintext);
}

@end
