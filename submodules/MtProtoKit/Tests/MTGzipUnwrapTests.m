#import <XCTest/XCTest.h>

#import <MtProtoKit/MTGzip.h>
#import <MtProtoKit/MTTransport.h>

#import "MTInternalMessageParser.h"
#import "MTBufferReader.h"
#import "MTBuffer.h"

static NSData *zeroData(NSUInteger length) {
    return [[NSMutableData alloc] initWithLength:length];
}

static NSData *randomData(NSUInteger length) {
    NSMutableData *data = [[NSMutableData alloc] initWithLength:length];
    if (length != 0) {
        arc4random_buf(data.mutableBytes, length);
    }
    return data;
}

// gzip_packed#3072cfa1 packed_data:bytes, serialized by the module's own TL
// writer so the fixture is what production code emits.
static NSData *gzipPackedWrapper(NSData *packed) {
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendInt32:(int32_t)0x3072cfa1];
    [buffer appendTLBytes:packed];
    return buffer.data;
}

@interface MTGzipUnwrapTests : XCTestCase
@end

@implementation MTGzipUnwrapTests

- (void)testNonGzipDataPassesThroughUnchanged {
    NSData *plain = randomData(40);
    XCTAssertEqualObjects([MTInternalMessageParser unwrapMessage:plain], plain);
    NSData *tiny = randomData(3);
    XCTAssertEqualObjects([MTInternalMessageParser unwrapMessage:tiny], tiny);
    XCTAssertEqualObjects([MTInternalMessageParser unwrapMessage:[NSData data]], [NSData data]);
}

- (void)testGzipPackedWrapperRoundTripsForBothLengthForms {
    // Random data does not compress, so the packed size tracks the payload size:
    // 16 bytes stays under the 254-byte short form, the others take the 0xfe form.
    NSUInteger payloadLengths[] = { 16, 400, 10000 };
    for (NSUInteger i = 0; i < sizeof(payloadLengths) / sizeof(payloadLengths[0]); i++) {
        NSData *payload = randomData(payloadLengths[i]);
        NSData *packed = [MTGzip compress:payload];
        XCTAssertNotNil(packed);
        XCTAssertEqual(packed.length >= 254, payloadLengths[i] >= 254, @"length form for %lu", (unsigned long)payloadLengths[i]);
        XCTAssertEqualObjects([MTInternalMessageParser unwrapMessage:gzipPackedWrapper(packed)], payload, @"payload length %lu", (unsigned long)payloadLengths[i]);
    }
    // Highly compressible data: a large payload inside a small wrapper.
    NSData *zeros = zeroData(500000);
    XCTAssertEqualObjects([MTInternalMessageParser unwrapMessage:gzipPackedWrapper([MTGzip compress:zeros])], zeros);
}

- (void)testTruncatedGzipPackedWrappersReturnNilWithoutRaising {
    uint8_t signature[4] = { 0xa1, 0xcf, 0x72, 0x30 };
    NSMutableArray<NSData *> *truncated = [[NSMutableArray alloc] init];

    // Signature and nothing else.
    [truncated addObject:[NSData dataWithBytes:signature length:4]];

    // Long-form marker with only one of its three length bytes.
    uint8_t longMarkerShort[6] = { 0xa1, 0xcf, 0x72, 0x30, 0xfe, 0x10 };
    [truncated addObject:[NSData dataWithBytes:longMarkerShort length:6]];

    // Short form declaring 10 bytes with 3 present.
    uint8_t shortLying[8] = { 0xa1, 0xcf, 0x72, 0x30, 0x0a, 0x01, 0x02, 0x03 };
    [truncated addObject:[NSData dataWithBytes:shortLying length:8]];

    // Long form declaring 0xffffff bytes (16 MiB - 1) with 4 present.
    uint8_t longLying[12] = { 0xa1, 0xcf, 0x72, 0x30, 0xfe, 0xff, 0xff, 0xff, 0x01, 0x02, 0x03, 0x04 };
    [truncated addObject:[NSData dataWithBytes:longLying length:12]];

    // A well-formed wrapper with its packed data cut short of the declared length.
    NSData *wrapper = gzipPackedWrapper([MTGzip compress:randomData(300)]);
    [truncated addObject:[wrapper subdataWithRange:NSMakeRange(0, wrapper.length - 8)]];

    for (NSData *data in truncated) {
        XCTAssertNoThrow((void)[MTInternalMessageParser unwrapMessage:data], @"%@", data);
        XCTAssertNil([MTInternalMessageParser unwrapMessage:data], @"%@", data);
    }
}

- (void)testTruncatedGzipMemberIsRejectedByTheInflater {
    // The wrapper's TL length is consistent with its contents; the gzip member
    // inside is what is cut short, so this reaches zlib and must come back nil
    // from the stream-end check rather than from the length check.
    NSData *packed = [MTGzip compress:randomData(3000)];
    NSData *cutMember = [packed subdataWithRange:NSMakeRange(0, packed.length - 10)];
    XCTAssertNil([MTGzip decompress:cutMember]);
    XCTAssertNil([MTInternalMessageParser unwrapMessage:gzipPackedWrapper(cutMember)]);
}

- (void)testMalformedGzipPayloadReturnsNil {
    NSData *wrapper = gzipPackedWrapper(randomData(64));
    XCTAssertNil([MTInternalMessageParser unwrapMessage:wrapper]);
    XCTAssertNil([MTGzip decompress:randomData(64)]);
    XCTAssertNil([MTGzip decompress:[NSData data]]);
}

- (void)testDecompressRefusesOutputAboveTheCeiling {
    NSData *twoMiB = zeroData(2 * 1024 * 1024);
    NSData *packed = [MTGzip compress:twoMiB];
    XCTAssertNotNil(packed);
    XCTAssertTrue(packed.length < 16 * 1024, @"zeros should compress far below the output size");

    XCTAssertNil([MTGzip decompress:packed maxOutputLength:1024 * 1024]);
    XCTAssertNil([MTGzip decompress:packed maxOutputLength:2 * 1024 * 1024 - 1]);
    XCTAssertEqualObjects([MTGzip decompress:packed maxOutputLength:2 * 1024 * 1024], twoMiB);
    XCTAssertEqualObjects([MTGzip decompress:packed maxOutputLength:4 * 1024 * 1024], twoMiB);
}

- (void)testUnwrapAppliesTheUnpackedMessageCeiling {
    // The ceiling is a policy of its own (the transport limit bounds the
    // compressed frame); pin its relationship to the frame size and that the
    // wrapper path enforces it.
    XCTAssertEqual(MTMaxUnpackedMessageLength, 2 * MTMaxTransportPayloadLength);

    NSData *over = zeroData(MTMaxUnpackedMessageLength + 16);
    XCTAssertNil([MTInternalMessageParser unwrapMessage:gzipPackedWrapper([MTGzip compress:over])]);

    NSData *under = zeroData(MTMaxUnpackedMessageLength);
    XCTAssertEqual([MTInternalMessageParser unwrapMessage:gzipPackedWrapper([MTGzip compress:under])].length, under.length);
}

- (void)testBufferReaderDecodesLongTLLengthsUnsigned {
    // 0xfe + 3-byte length >= 0x800000 used to go negative through a signed shift
    // and be rejected even with every byte present.
    NSUInteger length = 0x800010;
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendTLBytes:zeroData(length)];
    MTBufferReader *reader = [[MTBufferReader alloc] initWithData:buffer.data];
    NSData *value = nil;
    XCTAssertTrue([reader readTLBytes:&value]);
    XCTAssertEqual(value.length, length);
}

- (void)testBufferReaderRejectsOversizedTLBytesBeforeAllocating {
    // 0xfe + 3-byte length claiming 0xffffff bytes, with 2 bytes of body.
    uint8_t lying[6] = { 0xfe, 0xff, 0xff, 0xff, 0x01, 0x02 };
    MTBufferReader *reader = [[MTBufferReader alloc] initWithData:[NSData dataWithBytes:lying length:6]];
    NSData *value = nil;
    XCTAssertFalse([reader readTLBytes:&value]);
    XCTAssertNil(value);

    // Body present but the mandatory padding missing is also a truncation:
    // prefix (1) + "ab" (2) = 3 bytes, so one padding byte is due.
    uint8_t unpadded[3] = { 0x02, 'a', 'b' };
    MTBufferReader *unpaddedReader = [[MTBufferReader alloc] initWithData:[NSData dataWithBytes:unpadded length:3]];
    XCTAssertFalse([unpaddedReader readTLBytes:&value]);

    // Prefix (1) + "abc" (3) = 4 bytes needs no padding and reads as-is.
    uint8_t exact[4] = { 0x03, 'a', 'b', 'c' };
    MTBufferReader *exactReader = [[MTBufferReader alloc] initWithData:[NSData dataWithBytes:exact length:4]];
    XCTAssertTrue([exactReader readTLBytes:&value]);
    XCTAssertEqualObjects(value, [NSData dataWithBytes:"abc" length:3]);

    // A short-form string with padding reads and consumes exactly the padding.
    uint8_t good[8] = { 0x02, 'a', 'b', 0x00, 0x11, 0x22, 0x33, 0x44 };
    MTBufferReader *goodReader = [[MTBufferReader alloc] initWithData:[NSData dataWithBytes:good length:8]];
    XCTAssertTrue([goodReader readTLBytes:&value]);
    XCTAssertEqualObjects(value, [NSData dataWithBytes:"ab" length:2]);
    XCTAssertEqual([goodReader readRest].length, (NSUInteger)4);
}

- (void)testBufferReaderReadDataChecksBeforeAllocating {
    MTBufferReader *reader = [[MTBufferReader alloc] initWithData:randomData(10)];
    XCTAssertNil([reader readData:11]);
    XCTAssertEqual([reader readData:4].length, (NSUInteger)4);
    XCTAssertEqual([reader readData:6].length, (NSUInteger)6);
    XCTAssertNil([reader readData:1]);
    XCTAssertEqual([reader readData:0].length, (NSUInteger)0);
}

@end
