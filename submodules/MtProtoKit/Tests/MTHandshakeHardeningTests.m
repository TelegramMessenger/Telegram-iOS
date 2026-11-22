#import <XCTest/XCTest.h>

#import <MtProtoKit/MTEncryption.h>
#import <MtProtoKit/MTDatacenterAuthMessageService.h>
#import <MtProtoKit/MTBindKeyMessageService.h>
#import <MtProtoKit/MTIncomingMessage.h>
#import <MtProtoKit/MTRpcError.h>
#import <MtProtoKit/MTTcpTransport.h>

#import "MTTestSupport.h"
#import "MTBuffer.h"
#import "MTResPqMessage.h"
#import "MTServerDhParamsMessage.h"

static const NSInteger kDatacenterId = 2;
static const int32_t kStagePQ = 1;
static const int32_t kStageReqDH = 2;

@interface MTHandshakeTestEncryptionProvider : NSObject

@property (nonatomic) NSInteger bignumContextRequests;

@end

@implementation MTHandshakeTestEncryptionProvider

- (id)createBignumContext {
    _bignumContextRequests += 1;
    return nil;
}

- (id)parseRSAPublicKey:(NSString *)publicKey {
    return nil;
}

@end

static NSData *randomBytes(NSUInteger length) {
    NSMutableData *data = [[NSMutableData alloc] initWithLength:length];
    arc4random_buf(data.mutableBytes, length);
    return data;
}

static NSData *bytesOfUInt64(uint64_t value, NSUInteger length) {
    NSMutableData *data = [[NSMutableData alloc] initWithLength:length];
    for (NSUInteger i = 0; i < length && i < 8; i++) {
        ((uint8_t *)data.mutableBytes)[length - 1 - i] = (uint8_t)(value >> (8 * i));
    }
    return data;
}

static NSData *concat(NSArray<NSData *> *parts) {
    NSMutableData *result = [[NSMutableData alloc] init];
    for (NSData *part in parts) {
        [result appendData:part];
    }
    return result;
}

@interface MTHandshakeHardeningTests : XCTestCase
@end

@implementation MTHandshakeHardeningTests {
    MTHandshakeTestEncryptionProvider *_provider;
    MTContext *_context;
    MTProto *_proto;
    MTDatacenterAuthMessageService *_service;
    NSData *_nonce;
    NSData *_serverNonce;
    NSData *_newNonce;
}

- (void)setUp {
    [super setUp];
    _provider = [[MTHandshakeTestEncryptionProvider alloc] init];
    _context = MTTestMakeContextWithEncryptionProvider(false, (id<EncryptionProvider>)_provider);
    _proto = [[MTProto alloc] initWithContext:_context datacenterId:kDatacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    _proto.useUnauthorizedMode = true;
    _service = [[MTDatacenterAuthMessageService alloc] initWithContext:_context tempAuth:false];
    _nonce = randomBytes(16);
    _serverNonce = randomBytes(16);
    _newNonce = randomBytes(32);
    MTDatacenterAuthMessageService *service = _service;
    MTProto *proto = _proto;
    MTTestOnManagerQueue(^{
        [service mtProtoDidAddService:proto];
    });
}

- (void)tearDown {
    [_proto stop];
    [super tearDown];
}

- (int32_t)stage {
    __block int32_t stage = -1;
    MTTestOnManagerQueue(^{
        stage = [[self->_service valueForKey:@"_stage"] intValue];
    });
    return stage;
}

- (void)enterStage:(int32_t)stage {
    MTDatacenterAuthMessageService *service = _service;
    NSData *nonce = _nonce;
    NSData *serverNonce = _serverNonce;
    NSData *newNonce = _newNonce;
    MTTestOnManagerQueue(^{
        [service setValue:@(stage) forKey:@"_stage"];
        [service setValue:nonce forKey:@"_nonce"];
        if (stage == kStageReqDH) {
            [service setValue:serverNonce forKey:@"_serverNonce"];
            [service setValue:newNonce forKey:@"_newNonce"];
        }
    });
}

- (void)deliver:(id)body {
    MTIncomingMessage *message = [[MTIncomingMessage alloc] initWithMessageId:1 seqNo:0 authKeyId:0 sessionId:0 salt:0 timestamp:0.0 size:0 body:body];
    MTDatacenterAuthMessageService *service = _service;
    MTProto *proto = _proto;
    MTTestOnManagerQueue(^{
        [service mtProto:proto receivedMessage:message authInfoSelector:MTDatacenterAuthInfoSelectorPersistent networkType:0];
    });
}

- (bool)requestsMessage {
    __block bool result = false;
    MTDatacenterAuthMessageService *service = _service;
    MTProto *proto = _proto;
    MTTestOnManagerQueue(^{
        result = [service mtProtoMessageTransaction:proto authInfoSelector:MTDatacenterAuthInfoSelectorPersistent sessionInfo:nil scheme:nil] != nil;
    });
    return result;
}

- (void)failHandshake {
    MTDatacenterAuthMessageService *service = _service;
    MTProto *proto = _proto;
    MTTestOnManagerQueue(^{
        [service mtProto:proto protocolErrorReceived:-404];
    });
}

- (NSData *)encryptedAnswer:(NSData *)answerWithHash {
    NSData *newNonceServerNonceHash = MTSha1(concat(@[_newNonce, _serverNonce]));
    NSData *serverNonceNewNonceHash = MTSha1(concat(@[_serverNonce, _newNonce]));
    NSData *key = concat(@[newNonceServerNonceHash, [serverNonceNewNonceHash subdataWithRange:NSMakeRange(0, 12)]]);
    NSData *iv = concat(@[[serverNonceNewNonceHash subdataWithRange:NSMakeRange(12, 8)], MTSha1(concat(@[_newNonce, _newNonce])), [_newNonce subdataWithRange:NSMakeRange(0, 4)]]);
    return MTAesEncrypt(answerWithHash, key, iv);
}

- (NSData *)serverDhInnerData {
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendInt32:(int32_t)0xb5890dba];
    [buffer appendBytes:_nonce.bytes length:_nonce.length];
    [buffer appendBytes:_serverNonce.bytes length:_serverNonce.length];
    [buffer appendInt32:3];
    [buffer appendTLBytes:randomBytes(256)];
    [buffer appendTLBytes:randomBytes(256)];
    [buffer appendInt32:(int32_t)[NSDate date].timeIntervalSince1970];
    return buffer.data;
}

- (NSData *)answerWithHash:(NSData *)answer padding:(NSUInteger)padding {
    return concat(@[MTSha1(answer), answer, randomBytes(padding)]);
}

- (void)testFactorizeRejectsDegenerateValues {
    uint64_t values[] = { 0, 1, 2, 3, ((uint64_t)1) << 63, (((uint64_t)1) << 63) + 1, UINT64_MAX };
    for (size_t i = 0; i < sizeof(values) / sizeof(values[0]); i++) {
        uint64_t p = 0;
        uint64_t q = 0;
        XCTAssertFalse(MTFactorize(values[i], &p, &q), @"%llu", values[i]);
    }
}

- (void)testFactorizeSplitsEvenAndOddProducts {
    struct { uint64_t pq; uint64_t p; uint64_t q; } cases[] = {
        { 4, 2, 2 },
        { 6, 2, 3 },
        { 15, 3, 5 },
        { 0x17ED48941A08F981ULL, 1229739323ULL, 1402015859ULL },
        { 2147483647ULL * 2147483629ULL, 2147483629ULL, 2147483647ULL }
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
        uint64_t p = 0;
        uint64_t q = 0;
        XCTAssertTrue(MTFactorize(cases[i].pq, &p, &q), @"%llu", cases[i].pq);
        XCTAssertEqual(p, cases[i].p);
        XCTAssertEqual(q, cases[i].q);
    }
}

- (void)testFactorizeGivesUpOnALargePrimeInBoundedTime {
    uint64_t p = 0;
    uint64_t q = 0;
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    XCTAssertFalse(MTFactorize(9223372036854775783ULL, &p, &q));
    XCTAssertLessThan(CFAbsoluteTimeGetCurrent() - start, 10.0);
}

- (void)testHostilePqIsRejectedBeforeFactorizing {
    NSArray<NSData *> *hostile = @[
        [NSData data],
        bytesOfUInt64(0, 1),
        bytesOfUInt64(1, 1),
        bytesOfUInt64(3, 1),
        bytesOfUInt64(((uint64_t)1) << 63, 8),
        bytesOfUInt64(UINT64_MAX, 8),
        concat(@[bytesOfUInt64(1, 1), bytesOfUInt64(0x17ED48941A08F981ULL, 8)])
    ];
    for (NSData *pq in hostile) {
        [self enterStage:kStagePQ];
        _provider.bignumContextRequests = 0;
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self deliver:[[MTResPqMessage alloc] initWithNonce:_nonce serverNonce:_serverNonce pq:pq serverPublicKeyFingerprints:@[@(0)]]];
        XCTAssertLessThan(CFAbsoluteTimeGetCurrent() - start, 1.0, @"%@", pq);
        XCTAssertEqual(_provider.bignumContextRequests, 1, @"%@ went past the pq checks", pq);
        XCTAssertEqual([self stage], kStagePQ);
    }
}

- (void)testValidPqIsFactorizedAndUsed {
    [self enterStage:kStagePQ];
    _provider.bignumContextRequests = 0;
    [self deliver:[[MTResPqMessage alloc] initWithNonce:_nonce serverNonce:_serverNonce pq:bytesOfUInt64(0x17ED48941A08F981ULL, 8) serverPublicKeyFingerprints:@[@(0)]]];
    XCTAssertGreaterThan(_provider.bignumContextRequests, 1);
}

- (void)testShortServerDhAnswersAreRejectedWithoutThrowing {
    for (NSUInteger length = 16; length <= 96; length += 16) {
        [self enterStage:kStageReqDH];
        MTServerDhParamsOkMessage *body = [[MTServerDhParamsOkMessage alloc] initWithNonce:_nonce serverNonce:_serverNonce encryptedResponse:randomBytes(length)];
        XCTAssertNoThrow([self deliver:body], @"%d bytes", (int)length);
        XCTAssertEqual([self stage], kStagePQ);
    }
}

- (void)testServerDhAnswerIsParsedBeforeItsPaddingIsChecked {
    NSData *answer = [self serverDhInnerData];
    NSUInteger alignedPadding = (16 - (20 + answer.length) % 16) % 16;

    [self enterStage:kStageReqDH];
    _provider.bignumContextRequests = 0;
    [self deliver:[[MTServerDhParamsOkMessage alloc] initWithNonce:_nonce serverNonce:_serverNonce encryptedResponse:[self encryptedAnswer:[self answerWithHash:answer padding:alignedPadding]]]];
    XCTAssertGreaterThan(_provider.bignumContextRequests, 0, @"a well-formed answer reaches the DH checks");

    [self enterStage:kStageReqDH];
    _provider.bignumContextRequests = 0;
    [self deliver:[[MTServerDhParamsOkMessage alloc] initWithNonce:_nonce serverNonce:_serverNonce encryptedResponse:[self encryptedAnswer:[self answerWithHash:answer padding:alignedPadding + 16]]]];
    XCTAssertEqual(_provider.bignumContextRequests, 0, @"16 or more padding bytes are rejected");
    XCTAssertEqual([self stage], kStagePQ);

    NSMutableData *tampered = [[self answerWithHash:answer padding:alignedPadding] mutableCopy];
    ((uint8_t *)tampered.mutableBytes)[20 + answer.length - 1] ^= 1;
    [self enterStage:kStageReqDH];
    _provider.bignumContextRequests = 0;
    [self deliver:[[MTServerDhParamsOkMessage alloc] initWithNonce:_nonce serverNonce:_serverNonce encryptedResponse:[self encryptedAnswer:tampered]]];
    XCTAssertEqual(_provider.bignumContextRequests, 0, @"a hash mismatch is rejected");
}

- (void)testRepeatedHandshakeFailuresBackOff {
    XCTAssertTrue([self requestsMessage]);

    [self failHandshake];
    XCTAssertTrue([self requestsMessage], @"the first failure retries at once");

    [self failHandshake];
    XCTAssertFalse([self requestsMessage], @"the second failure waits before asking again");
    XCTAssertTrue(MTTestWaitUntil(3.0, ^bool{
        return [self requestsMessage];
    }));

    [self failHandshake];
    XCTAssertFalse([self requestsMessage]);
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{
        return [self requestsMessage];
    }));
    XCTAssertGreaterThan(CFAbsoluteTimeGetCurrent() - start, 1.5, @"the wait grows with each failure");
}

- (void)testUnauthorizedConnectionsDoNotTreatIncomingDataAsAuthenticated {
    MTContext *context = MTTestMakeContext(false);
    MTTestSetAddress(context, kDatacenterId, false);
    MTProto *unauthorized = [[MTProto alloc] initWithContext:context datacenterId:kDatacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    unauthorized.useUnauthorizedMode = true;
    [unauthorized resume];
    __block MTTransport *transport = nil;
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{
        MTTestOnManagerQueue(^{
            transport = [unauthorized valueForKey:@"_transport"];
        });
        return transport != nil;
    }));
    XCTAssertTrue(transport.incomingDataIsUnauthenticated);
    [unauthorized stop];

    [context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
    MTProto *authorized = [[MTProto alloc] initWithContext:context datacenterId:kDatacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    [authorized resume];
    transport = nil;
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{
        MTTestOnManagerQueue(^{
            transport = [authorized valueForKey:@"_transport"];
        });
        return transport != nil;
    }));
    XCTAssertFalse(transport.incomingDataIsUnauthenticated);
    [authorized stop];
}

- (MTBindKeyMessageService *)bindServiceOn:(MTProto *)proto results:(NSMutableArray<NSNumber *> *)results {
    MTDatacenterAuthKey *persistentKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:randomBytes(256) authKeyId:1 validUntilTimestamp:INT32_MAX notBound:false];
    MTBindKeyMessageService *service = [[MTBindKeyMessageService alloc] initWithPersistentKey:persistentKey ephemeralKey:proto.useExplicitAuthKey completion:^(bool success, MTRpcError *error) {
        @synchronized (results) {
            [results addObject:@(success)];
        }
    }];
    [proto addMessageService:service];
    MTTestOnManagerQueue(^{});
    return service;
}

- (MTProto *)bindProtoWithMedia:(bool)media {
    MTContext *context = MTTestMakeContext(true);
    MTProto *proto = [[MTProto alloc] initWithContext:context datacenterId:kDatacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    proto.useTempAuthKeys = true;
    proto.media = media;
    proto.useExplicitAuthKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:randomBytes(256) authKeyId:2 validUntilTimestamp:INT32_MAX notBound:true];
    return proto;
}

- (void)rejectKeyOn:(MTProto *)proto media:(bool)media {
    MTTransportScheme *scheme = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:MTTestMakeAddress(media) media:media];
    MTTestOnManagerQueue(^{
        [proto handleMissingKey:scheme];
    });
}

- (void)testOneUnconfirmedKeyRejectionDoesNotFinishABind {
    for (NSNumber *media in @[@false, @true]) {
        MTProto *proto = [self bindProtoWithMedia:media.boolValue];
        NSMutableArray<NSNumber *> *results = [[NSMutableArray alloc] init];
        [self bindServiceOn:proto results:results];
        [self rejectKeyOn:proto media:media.boolValue];
        @synchronized (results) {
            XCTAssertEqual(results.count, 0, @"media: %@", media);
        }
        [proto stop];
    }
}

- (void)testAConfirmedKeyRejectionFailsTheBindOnce {
    for (NSNumber *media in @[@false, @true]) {
        MTProto *proto = [self bindProtoWithMedia:media.boolValue];
        NSMutableArray<NSNumber *> *results = [[NSMutableArray alloc] init];
        [self bindServiceOn:proto results:results];
        [self rejectKeyOn:proto media:media.boolValue];
        [self rejectKeyOn:proto media:media.boolValue];
        [self rejectKeyOn:proto media:media.boolValue];
        @synchronized (results) {
            XCTAssertEqualObjects(results, @[@false], @"media: %@", media);
        }
        [proto stop];
    }
}

- (void)testAnAuthenticatedMessageClearsAnEarlierKeyRejection {
    MTProto *proto = [self bindProtoWithMedia:true];
    NSMutableArray<NSNumber *> *results = [[NSMutableArray alloc] init];
    MTBindKeyMessageService *service = [self bindServiceOn:proto results:results];
    [self rejectKeyOn:proto media:true];
    MTIncomingMessage *message = [[MTIncomingMessage alloc] initWithMessageId:1 seqNo:1 authKeyId:2 sessionId:0 salt:0 timestamp:0.0 size:0 body:[[NSObject alloc] init]];
    MTTestOnManagerQueue(^{
        [service mtProto:proto receivedMessage:message authInfoSelector:MTDatacenterAuthInfoSelectorEphemeralMedia networkType:0];
    });
    [self rejectKeyOn:proto media:true];
    @synchronized (results) {
        XCTAssertEqual(results.count, 0);
    }
    [proto stop];
}

@end
