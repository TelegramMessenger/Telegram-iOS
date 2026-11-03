#import <XCTest/XCTest.h>

#import <MtProtoKit/MTIncomingMessage.h>
#import <MtProtoKit/MTMessageTransaction.h>
#import <MtProtoKit/MTOutgoingMessage.h>
#import <MtProtoKit/MTRequest.h>
#import <MtProtoKit/MTRequestContext.h>
#import <MtProtoKit/MTRequestErrorContext.h>
#import <MtProtoKit/MTRequestMessageService.h>

#import "MTTestSupport.h"
#import "MTRpcResultMessage.h"
#import <MtProtoKit/MTPreparedMessage.h>

// `handOverRequests:` (a live engine switch away from MtProtoKit): nothing goes out under a new message
// id, a request without one leaves at once (as possibly run if it went out before), one with a message
// id waits for its answer.

static const NSInteger kHandoverDatacenterId = 2;

@interface MTRequestHandoverRelease : NSObject

@property (nonatomic, strong) MTRequest *request;
@property (nonatomic) bool mayHaveReachedServer;
@property (nonatomic) double retryAfter;

@end

@implementation MTRequestHandoverRelease
@end

@interface MTRequestHandoverTests : XCTestCase
{
    MTContext *_context;
    MTProto *_proto;
    MTRequestMessageService *_service;
    NSMutableArray<MTRequestHandoverRelease *> *_released;
    NSMutableArray<NSString *> *_completed;
}

@end

@implementation MTRequestHandoverTests

- (void)setUp {
    [super setUp];
    _context = MTTestMakeContext(true);
    MTTestSetAddress(_context, kHandoverDatacenterId, false);
    _proto = [[MTProto alloc] initWithContext:_context datacenterId:kHandoverDatacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    [_proto pause];
    _service = [[MTRequestMessageService alloc] initWithContext:_context];
    [_proto addMessageService:_service];
    _released = [[NSMutableArray alloc] init];
    _completed = [[NSMutableArray alloc] init];
    MTTestOnManagerQueue(^{});
}

- (void)tearDown {
    [_proto stop];
    [super tearDown];
}

- (MTRequest *)addRequest:(NSString *)name dependsOn:(NSString *)dependency messageId:(int64_t)messageId {
    MTRequest *request = [[MTRequest alloc] init];
    uint8_t body[8] = { 0x01, 0x02, 0x03, 0x04, 0, 0, 0, 0 };
    [request setPayload:[NSData dataWithBytes:body length:8] metadata:name shortMetadata:name responseParser:^id(NSData *data) {
        return data;
    }];
    request.shouldContinueExecutionWithErrorContext = ^bool(__unused MTRequestErrorContext *errorContext) {
        return true;
    };
    if (dependency != nil) {
        request.shouldDependOnRequest = ^bool(MTRequest *other) {
            return [other.metadata isEqual:dependency];
        };
    }
    NSMutableArray<NSString *> *completed = _completed;
    request.completed = ^(__unused id result, __unused MTRequestResponseInfo *info, MTRpcError *error) {
        @synchronized (completed) {
            [completed addObject:[NSString stringWithFormat:@"%@ %@", name, error == nil ? @"ok" : error.errorDescription]];
        }
    };
    [_service addRequest:request];
    MTTestOnManagerQueue(^{
        if (messageId != 0) {
            request.requestContext = [[MTRequestContext alloc] initWithMessageId:messageId messageSeqNo:1 transactionId:@(messageId) quickAckId:0];
            request.mayHaveReachedServer = true;
        }
    });
    return request;
}

- (void)handOver {
    NSMutableArray<MTRequestHandoverRelease *> *released = _released;
    [_service handOverRequests:^(MTRequest *request, bool mayHaveReachedServer, double retryAfter) {
        MTRequestHandoverRelease *entry = [[MTRequestHandoverRelease alloc] init];
        entry.request = request;
        entry.mayHaveReachedServer = mayHaveReachedServer;
        entry.retryAfter = retryAfter;
        @synchronized (released) {
            [released addObject:entry];
        }
    }];
    MTTestOnManagerQueue(^{});
}

- (NSArray<NSString *> *)releasedNames {
    NSMutableArray<NSString *> *names = [[NSMutableArray alloc] init];
    @synchronized (_released) {
        for (MTRequestHandoverRelease *entry in _released) {
            [names addObject:[NSString stringWithFormat:@"%@%@", entry.request.metadata, entry.mayHaveReachedServer ? @"!" : @""]];
        }
    }
    return names;
}

- (void)deliverResult:(int64_t)messageId data:(NSData *)data {
    MTRpcResultMessage *result = [[MTRpcResultMessage alloc] initWithRequestMessageId:messageId data:data];
    MTIncomingMessage *message = [[MTIncomingMessage alloc] initWithMessageId:messageId + 1 seqNo:1 authKeyId:0 sessionId:0 salt:0 timestamp:0.0 size:(NSInteger)data.length body:result];
    MTTestOnManagerQueue(^{
        [self->_service mtProto:self->_proto receivedMessage:message authInfoSelector:MTDatacenterAuthInfoSelectorEphemeralMain networkType:0];
    });
}

static NSData *rpcError(int32_t code, NSString *text) {
    NSMutableData *data = [[NSMutableData alloc] init];
    uint32_t constructor = 0x2144ca19;
    [data appendBytes:&constructor length:4];
    [data appendBytes:&code length:4];
    NSData *bytes = [text dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t length = (uint8_t)bytes.length;
    [data appendBytes:&length length:1];
    [data appendData:bytes];
    while (data.length % 4 != 0) {
        uint8_t zero = 0;
        [data appendBytes:&zero length:1];
    }
    return data;
}

- (MTMessageTransaction *)transaction {
    __block MTMessageTransaction *transaction = nil;
    MTTestOnManagerQueue(^{
        transaction = [self->_service mtProtoMessageTransaction:self->_proto authInfoSelector:MTDatacenterAuthInfoSelectorEphemeralMain sessionInfo:nil scheme:nil];
    });
    return transaction;
}

- (void)testRequestsWithoutAMessageIdLeaveAtOnceAndSentOnesWait {
    [self addRequest:@"sent" dependsOn:nil messageId:4000];
    [self addRequest:@"chained" dependsOn:@"sent" messageId:0];
    [self addRequest:@"fresh" dependsOn:nil messageId:0];
    [self handOver];
    XCTAssertEqualObjects([self releasedNames], (@[@"fresh"]), @"the call chained to one still waiting follows it");
    MTMessageTransaction *transaction = [self transaction];
    for (MTOutgoingMessage *message in transaction.messagePayload) {
        XCTAssertNotEqualObjects(message.metadata, @"chained", @"nothing goes out under a new message id");
        XCTAssertNotEqualObjects(message.metadata, @"fresh");
    }
    [self deliverResult:4000 data:[NSData dataWithBytes:(uint8_t[]){ 9, 9, 9, 9 } length:4]];
    XCTAssertTrue(MTTestWaitUntil(2.0, ^bool{ return [self releasedNames].count == 2; }));
    XCTAssertEqualObjects([self releasedNames], (@[@"fresh", @"chained"]));
    @synchronized (_completed) {
        XCTAssertEqualObjects(_completed, (@[@"sent ok"]), @"the answer completes the call it belongs to");
    }
}

- (void)testAtTheDeadlineWhatWentOutLeavesAsPossiblyRunBeforeTheCallsChainedToIt {
    [self addRequest:@"sent" dependsOn:nil messageId:4000];
    [self addRequest:@"chained" dependsOn:@"sent" messageId:0];
    [self handOver];
    XCTAssertEqualObjects([self releasedNames], (@[]));
    [_service releaseHandedOverRequests];
    MTTestOnManagerQueue(^{});
    XCTAssertEqualObjects([self releasedNames], (@[@"sent!", @"chained"]));
}

- (void)testARequestAddedAfterTheHandoverComesStraightBack {
    [self handOver];
    [self addRequest:@"late" dependsOn:nil messageId:0];
    XCTAssertEqualObjects([self releasedNames], (@[@"late"]));
}

- (void)testAFloodWaitTheRequestWaitsOutLeavesAsNotRunWithTheWaitLeft {
    [self addRequest:@"flooded" dependsOn:nil messageId:4000];
    [self handOver];
    [self deliverResult:4000 data:rpcError(420, @"FLOOD_WAIT_30")];
    XCTAssertEqualObjects([self releasedNames], (@[@"flooded"]), @"the server refused it: moving it runs it once");
    double retryAfter = 0.0;
    @synchronized (_released) {
        retryAfter = _released.firstObject.retryAfter;
    }
    XCTAssertTrue(retryAfter > 28.0 && retryAfter <= 30.0, @"%f", retryAfter);
}

- (void)testASentRequestWhoseConnectionMayHaveFailedLeavesAsPossiblyRun {
    [self addRequest:@"sent" dependsOn:nil messageId:4000];
    [self handOver];
    MTTestOnManagerQueue(^{
        [self->_service mtProtoAllTransactionsMayHaveFailed:self->_proto];
    });
    MTMessageTransaction *transaction = [self transaction];
    XCTAssertEqual(transaction.messagePayload.count, 0u, @"not sent again under a new message id");
    XCTAssertEqualObjects([self releasedNames], (@[@"sent!"]));
}

- (void)testRemovingARequestTheServiceAloneHoldsReadsNothingOfItAfterward {
    id internalId = nil;
    @autoreleasepool {
        internalId = [self addRequest:@"lone" dependsOn:nil messageId:4000].internalId;
    }
    [self handOver];
    [_service removeRequestByInternalId:internalId];
    MTTestOnManagerQueue(^{});
    XCTAssertEqualObjects([self releasedNames], (@[]));
    [_service releaseHandedOverRequests];
    MTTestOnManagerQueue(^{});
    XCTAssertEqualObjects([self releasedNames], (@[]), @"a removed request is not handed over");
}

- (void)testARequestWhoseMessageIdWasForgottenBeforeTheHandoverLeavesAsPossiblyRun {
    [self addRequest:@"sent" dependsOn:nil messageId:4000];
    [self addRequest:@"fresh" dependsOn:nil messageId:0];
    MTTestOnManagerQueue(^{
        [self->_service mtProtoAllTransactionsMayHaveFailed:self->_proto];
    });
    [self handOver];
    XCTAssertEqualObjects([self releasedNames], (@[@"sent!", @"fresh"]), @"a transport reset just before the switch does not make a call that went out look new");
}

- (void)testARequestSentInATransactionStaysPossiblyRunAfterItsMessageIdIsForgotten {
    [self addRequest:@"sent" dependsOn:nil messageId:0];
    MTMessageTransaction *transaction = [self transaction];
    XCTAssertEqual(transaction.messagePayload.count, 1u);
    MTOutgoingMessage *message = transaction.messagePayload.firstObject;
    MTPreparedMessage *prepared = [[MTPreparedMessage alloc] initWithData:message.data messageId:5000 seqNo:1 salt:0 requiresConfirmation:true hasHighPriority:false];
    MTTestOnManagerQueue(^{
        transaction.prepared(@{message.internalId: prepared});
        transaction.completion(@{message.internalId: @(1)}, @{message.internalId: prepared}, @{});
        [self->_service mtProtoAllTransactionsMayHaveFailed:self->_proto];
    });
    [self handOver];
    XCTAssertEqualObjects([self releasedNames], (@[@"sent!"]));
}

- (void)testARequestTheServerRefusedAndThatWentAgainLeavesAsNotRun {
    [self addRequest:@"refused" dependsOn:nil messageId:4000];
    [self deliverResult:4000 data:rpcError(420, @"FLOOD_WAIT_30")];
    [self handOver];
    XCTAssertEqualObjects([self releasedNames], (@[@"refused"]), @"the server answered it with a flood wait: it did not run");
}

- (void)testWithoutAHandoverTheSameRequestGoesOutAgainAsBefore {
    [self addRequest:@"sent" dependsOn:nil messageId:4000];
    MTTestOnManagerQueue(^{
        [self->_service mtProtoAllTransactionsMayHaveFailed:self->_proto];
    });
    MTMessageTransaction *transaction = [self transaction];
    XCTAssertEqual(transaction.messagePayload.count, 1u);
    XCTAssertEqualObjects([self releasedNames], (@[]));
}

@end
