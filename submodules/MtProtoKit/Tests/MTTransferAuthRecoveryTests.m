#import <XCTest/XCTest.h>

#import <MtProtoKit/MTRequest.h>
#import <MtProtoKit/MTRequestErrorContext.h>
#import <MtProtoKit/MTTcpTransport.h>

#import "MTTestSupport.h"

// A connection to a datacenter other than the master one needs an auth token,
// which the context transfers (exportAuthorization on the master, then
// importAuthorization on the destination). While it waits, MTProto holds
// MTProtoStateAwaitingDatacenterAuthToken and has no transport.
//
// Field report (log of 2026-09-24): DC 2 lost its temp media key (-404),
// MTProto.handleMissingKey dropped the DC 2 token (deliberately; see the
// comment there), and the re-transfer failed once with 500
// INTERDC_2_CALL_ERROR during a short server-side inter-DC outage. Nothing
// retried it, the four DC 2 download connections kept the awaiting flag, and
// they stayed without a transport for the ten hours until the app restarted.
//
// These tests replace only the transfer's network half (MTInternalInterfaces.h)
// and drive its outcome; the context, the waiting MTProtos and the transfer's
// own reporting are the production code.

static const NSInteger kMasterDatacenterId = 1;
static const NSInteger kMediaDatacenterId = 2;

// How long a waiting connection may take to ask for its token again after a
// transfer failed. The first retry must be quick enough that nobody notices,
// and the backoff has to fit inside this.
static const NSTimeInterval kRetryWindow = 10.0;

@interface MTTransferAuthRecoveryTests : XCTestCase
@end

@implementation MTTransferAuthRecoveryTests {
    MTContext *_context;
    MTTestActionRecorder *_recorder;
    NSMutableArray<MTProto *> *_protos;
    NSMutableArray<MTTestProtoObserver *> *_observers;
}

- (void)setUpContextWithTempAuthKeys:(bool)useTempAuthKeys {
    _protos = [[NSMutableArray alloc] init];
    _observers = [[NSMutableArray alloc] init];
    _context = MTTestMakeContext(useTempAuthKeys);
    _recorder = [[MTTestActionRecorder alloc] initWithContext:_context];
    MTTestSetAddress(_context, kMediaDatacenterId, true);
}

- (void)setUp {
    [super setUp];
    [self setUpContextWithTempAuthKeys:false];

    // DC 2 has a key, so the only thing a connection can be waiting for is the
    // token, which it does not have yet.
    [_context updateAuthInfoForDatacenterWithId:kMediaDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
}

- (void)tearDown {
    for (MTProto *proto in _protos) {
        [proto stop];
    }
    _context.transferAuthActionFactory = nil;
    _context.authActionFactory = nil;
    _context = nil;
    [super tearDown];
}

// A download worker's connection, as TelegramCore's Download builds it.
- (MTProto *)makeDownloadConnection:(MTTestProtoObserver **)observerOut {
    MTProto *proto = [[MTProto alloc] initWithContext:_context datacenterId:kMediaDatacenterId usageCalculationInfo:nil requiredAuthToken:@(kMediaDatacenterId) authTokenMasterDatacenterId:kMasterDatacenterId];
    proto.useTempAuthKeys = _context.useTempAuthKeys;
    proto.media = true;
    MTTestProtoObserver *observer = [[MTTestProtoObserver alloc] init];
    proto.delegate = observer;
    [_protos addObject:proto];
    [_observers addObject:observer];
    *observerOut = observer;
    return proto;
}

#pragma mark - Controls

// The harness itself: a waiting connection starts a transfer, and a successful
// one gives it a transport.
- (void)testSuccessfulTransferReleasesTheWaitingConnection {
    MTTestProtoObserver *observer = nil;
    MTProto *proto = [self makeDownloadConnection:&observer];
    [proto resume];

    XCTAssertTrue([_recorder waitForTransferCount:1 timeout:5.0], @"a connection without its token must ask for one");
    XCTAssertEqual([_recorder transferAtIndex:0].destinationDatacenterId, kMediaDatacenterId);
    XCTAssertFalse(observer.hasTransport, @"no transport while the token is missing");

    [[_recorder transferAtIndex:0] succeed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return observer.hasTransport; }), @"a transferred token must release the waiting connection");
    XCTAssertEqual([_recorder transferCount], 1u);
}

// Why restarting the app helped: a connection created after the failure asks
// for the token itself.
- (void)testConnectionCreatedAfterAFailedTransferAsksAgain {
    MTTestProtoObserver *firstObserver = nil;
    MTProto *first = [self makeDownloadConnection:&firstObserver];
    [first resume];
    XCTAssertTrue([_recorder waitForTransferCount:1 timeout:5.0]);

    [[_recorder transferAtIndex:0] failWithError];

    MTTestProtoObserver *secondObserver = nil;
    MTProto *second = [self makeDownloadConnection:&secondObserver];
    [second resume];

    XCTAssertTrue([_recorder waitForTransferCount:2 timeout:kRetryWindow], @"a new connection must get a new transfer");
    if ([_recorder transferCount] < 2) {
        return;
    }
    [[_recorder transferAtIndex:1] succeed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return secondObserver.hasTransport; }));
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return firstObserver.hasTransport; }), @"the token update releases every waiting connection");
}

#pragma mark - Fix 1: a 500 does not end the transfer

// exportAuthorization and importAuthorization answered 500 INTERDC_x_CALL_ERROR
// during the outage. The app's own requests retry a 500 after a delay; the
// transfer requests had no policy at all, so the first 500 failed the transfer.
- (void)testTransferRequestsRetryInternalServerErrors {
    MTRequest *request = [[MTRequest alloc] init];
    [MTDatacenterTransferAuthAction applyRetryPolicyToRequest:request];

    XCTAssertNotNil(request.shouldContinueExecutionWithErrorContext, @"without a policy MTRequestMessageService fails a request on its first 500");
    if (request.shouldContinueExecutionWithErrorContext == nil) {
        return;
    }
    MTRequestErrorContext *errorContext = [[MTRequestErrorContext alloc] init];
    errorContext.internalServerErrorCount = 25;
    XCTAssertTrue(request.shouldContinueExecutionWithErrorContext(errorContext), @"a 500 must be retried however many times it repeats");
}

#pragma mark - Fix 2: a waiting connection always asks again

// The live case: the transfer fails while the connections are waiting.
- (void)testFailedTransferIsRetriedWhileConnectionsWait {
    NSMutableArray<MTTestProtoObserver *> *observers = [[NSMutableArray alloc] init];
    for (int i = 0; i < 4; i++) {
        MTTestProtoObserver *observer = nil;
        MTProto *proto = [self makeDownloadConnection:&observer];
        [proto resume];
        [observers addObject:observer];
    }
    XCTAssertTrue([_recorder waitForTransferCount:1 timeout:5.0]);
    // One transfer per datacenter, however many connections wait on it.
    XCTAssertFalse([_recorder waitForTransferCount:2 timeout:0.5]);

    [[_recorder transferAtIndex:0] failWithError];

    XCTAssertTrue([_recorder waitForTransferCount:2 timeout:kRetryWindow], @"a failed transfer must be tried again while connections still wait for the token");
    if ([_recorder transferCount] < 2) {
        return;
    }
    // Still one transfer at a time.
    XCTAssertFalse([_recorder waitForTransferCount:3 timeout:0.5]);
    [[_recorder transferAtIndex:1] succeed];

    for (MTTestProtoObserver *observer in observers) {
        XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return observer.hasTransport; }), @"every waiting connection must get a transport once the token arrives");
    }
}

// The exact timeline of the field log: the transfer failed (01:40:32), the app
// went to background and paused the workers (01:41:07), and the next morning
// it resumed them (12:07:06).
- (void)testConnectionPausedAcrossAFailedTransferAsksAgainOnResume {
    MTTestProtoObserver *observer = nil;
    MTProto *proto = [self makeDownloadConnection:&observer];
    [proto resume];
    XCTAssertTrue([_recorder waitForTransferCount:1 timeout:5.0]);

    [[_recorder transferAtIndex:0] failWithError];
    [proto pause];
    [proto resume];

    XCTAssertTrue([_recorder waitForTransferCount:2 timeout:kRetryWindow], @"a resumed connection that still lacks its token must ask for it again");
    if ([_recorder transferCount] < 2) {
        return;
    }
    [[_recorder transferAtIndex:1] succeed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return observer.hasTransport; }));
}

// A paused connection does not drive retries; it asks when it resumes, however
// long after the failure that is.
- (void)testConnectionPausedWhenTheRetryIsDueAsksOnResume {
    MTTestProtoObserver *observer = nil;
    MTProto *proto = [self makeDownloadConnection:&observer];
    [proto resume];
    XCTAssertTrue([_recorder waitForTransferCount:1 timeout:5.0]);

    [proto pause];
    [[_recorder transferAtIndex:0] failWithError];

    XCTAssertFalse([_recorder waitForTransferCount:2 timeout:3.0], @"no connection is active, so nothing needs the token yet");

    [proto resume];

    XCTAssertTrue([_recorder waitForTransferCount:2 timeout:kRetryWindow], @"resuming must ask for the token again");
    if ([_recorder transferCount] < 2) {
        return;
    }
    [[_recorder transferAtIndex:1] succeed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return observer.hasTransport; }));
}

// removeTokenForDatacenterWithId cancels a transfer in flight without
// reporting anything. The connections that were waiting on it must still get
// their token.
- (void)testCancelledTransferLetsWaitingConnectionsAskAgain {
    MTTestProtoObserver *observer = nil;
    MTProto *proto = [self makeDownloadConnection:&observer];
    [proto resume];
    XCTAssertTrue([_recorder waitForTransferCount:1 timeout:5.0]);

    [_context removeTokenForDatacenterWithId:kMediaDatacenterId];

    XCTAssertTrue([_recorder waitForTransferCount:2 timeout:kRetryWindow], @"a cancelled transfer must be replaced while connections wait for the token");
    if ([_recorder transferCount] < 2) {
        return;
    }
    [[_recorder transferAtIndex:1] succeed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return observer.hasTransport; }));
}

// The 401 path: a request answered AUTH_KEY_UNREGISTERED makes TelegramCore's
// Download drop the token and ask for a transfer itself
// (requestMessageServiceAuthorizationRequired), while the connection keeps its
// transport and never sets the awaiting flag. The parked request waits for the
// token, so a failed transfer must still be retried.
- (void)testTokenDroppedAfterA401IsRetriedAfterAFailedTransfer {
    [_context updateAuthTokenForDatacenterWithId:kMediaDatacenterId authToken:@(kMediaDatacenterId)];
    MTTestProtoObserver *observer = nil;
    MTProto *proto = [self makeDownloadConnection:&observer];
    [proto resume];
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return observer.hasTransport; }));
    XCTAssertEqual([_recorder transferCount], 0u);

    // What Download.requestMessageServiceAuthorizationRequired does.
    [_context updateAuthTokenForDatacenterWithId:kMediaDatacenterId authToken:nil];
    [_context authTokenForDatacenterWithIdRequired:kMediaDatacenterId authToken:@(kMediaDatacenterId) masterDatacenterId:kMasterDatacenterId];
    XCTAssertTrue([_recorder waitForTransferCount:1 timeout:5.0]);

    [[_recorder transferAtIndex:0] failWithError];

    XCTAssertTrue([_recorder waitForTransferCount:2 timeout:kRetryWindow], @"the connection still lacks its token, so the transfer must be retried");
}

#pragma mark - The whole field sequence

// Everything from the field log, entered the way it happened: a working DC 2
// download connection gets a -404 for its temp media key, handleMissingKey
// drops the key and the token, the key comes back, and the token transfer
// fails once. The connection must end up working again.
- (void)testTempKeyLossWithAFailedTokenTransferRecovers {
    [self tearDown];
    [self setUpContextWithTempAuthKeys:true];

    [_context updateAuthInfoForDatacenterWithId:kMediaDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
    [_context updateAuthInfoForDatacenterWithId:kMediaDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorEphemeralMedia];
    [_context updateAuthTokenForDatacenterWithId:kMediaDatacenterId authToken:@(kMediaDatacenterId)];

    MTTestProtoObserver *observer = nil;
    MTProto *proto = [self makeDownloadConnection:&observer];
    [proto resume];
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return observer.hasTransport; }), @"with a key and a token the connection works");

    MTTransportScheme *scheme = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:MTTestMakeAddress(true) media:true];
    MTTestOnManagerQueue(^{
        [proto handleMissingKey:scheme];
    });

    // The temp media key is recreated (auth action) and the token re-imported.
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0], @"a lost temp key must be recreated");
    XCTAssertTrue([_recorder waitForTransferCount:1 timeout:5.0], @"handleMissingKey drops the token of a non-master datacenter, so it is transferred again");
    if ([_recorder authActionCount] < 1 || [_recorder transferCount] < 1) {
        return;
    }
    XCTAssertEqual([_recorder authActionAtIndex:0].selector, MTDatacenterAuthInfoSelectorEphemeralMedia);
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return !observer.hasTransport; }), @"no transport while the token is missing");

    [[_recorder authActionAtIndex:0] succeed];
    [[_recorder transferAtIndex:0] failWithError];

    XCTAssertTrue([_recorder waitForTransferCount:2 timeout:kRetryWindow], @"the failed transfer must be retried");
    if ([_recorder transferCount] < 2) {
        return;
    }
    [[_recorder transferAtIndex:1] succeed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return observer.hasTransport; }), @"the connection must work again");
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return !MTTestIsWaiting(proto); }), @"and no longer wait for anything");
}

@end
