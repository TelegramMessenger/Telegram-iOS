#import <XCTest/XCTest.h>

#import <MtProtoKit/MTTcpTransport.h>

#import "MTTestSupport.h"

// A connection whose temp key is lost (-404) waits in
// MTProtoStateAwaitingDatacenterAuthorization until the context has a new key
// for it. The key comes from one MTDatacenterAuthAction per (datacenter,
// selector): a DH exchange, then auth.bindTempAuthKey. When the bind failed,
// the context dropped the action and told nobody, so every connection waiting
// on that key stayed unable to send until the app restarted - the same shape
// as the token-transfer failure in MTTransferAuthRecoveryTests, and on any
// datacenter, the master one included.

static const NSInteger kMasterDatacenterId = 1;
static const NSTimeInterval kRetryWindow = 10.0;

@interface MTAuthKeyRecoveryTests : XCTestCase
@end

@implementation MTAuthKeyRecoveryTests {
    MTContext *_context;
    MTTestActionRecorder *_recorder;
    MTProto *_proto;
}

- (void)setUp {
    [super setUp];
    _context = MTTestMakeContext(true);
    _recorder = [[MTTestActionRecorder alloc] initWithContext:_context];
    MTTestSetAddress(_context, kMasterDatacenterId, false);
    [_context updateAuthInfoForDatacenterWithId:kMasterDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
    [_context updateAuthInfoForDatacenterWithId:kMasterDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorEphemeralMain];

    // The main connection to the master datacenter.
    _proto = [[MTProto alloc] initWithContext:_context datacenterId:kMasterDatacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    _proto.useTempAuthKeys = true;
    [_proto resume];
}

- (void)tearDown {
    [_proto stop];
    _context.transferAuthActionFactory = nil;
    _context.authActionFactory = nil;
    _context = nil;
    [super tearDown];
}

- (void)loseTempKey {
    MTTransportScheme *scheme = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:MTTestMakeAddress(false) media:false];
    MTProto *proto = _proto;
    MTTestOnManagerQueue(^{
        [proto handleMissingKey:scheme];
    });
}

// The harness itself: a lost temp key is recreated and the connection stops
// waiting.
- (void)testRecreatedKeyReleasesTheWaitingConnection {
    XCTAssertFalse(MTTestIsWaiting(_proto));

    [self loseTempKey];

    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0], @"a lost temp key must be recreated");
    if ([_recorder authActionCount] < 1) {
        return;
    }
    XCTAssertEqual([_recorder authActionAtIndex:0].selector, MTDatacenterAuthInfoSelectorEphemeralMain);
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return MTTestIsWaiting(self->_proto); }), @"the connection waits for the new key");

    [[_recorder authActionAtIndex:0] succeed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return !MTTestIsWaiting(self->_proto); }));
}

// bindTempAuthKey fails (here a 500) while the connection is active.
- (void)testFailedKeyCreationIsRetriedWhileAConnectionWaits {
    [self loseTempKey];
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0]);
    if ([_recorder authActionCount] < 1) {
        return;
    }

    [[_recorder authActionAtIndex:0] failWithBindError:[[MTRpcError alloc] initWithErrorCode:500 errorDescription:@"INTERNAL_SERVER_ERROR"]];

    XCTAssertTrue([_recorder waitForAuthActionCount:2 timeout:kRetryWindow], @"a failed key creation must be tried again while a connection still waits for the key");
    if ([_recorder authActionCount] < 2) {
        return;
    }
    XCTAssertEqual([_recorder authActionAtIndex:1].selector, MTDatacenterAuthInfoSelectorEphemeralMain);
    [[_recorder authActionAtIndex:1] succeed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return !MTTestIsWaiting(self->_proto); }), @"the new key must release the connection");
}

// ENCRYPTED_MESSAGE_INVALID: the server no longer knows the permanent key, so
// binding a new temp key to it can never succeed. Retrying on a timer would
// run a full key exchange every minute for as long as the app is active.
- (void)testBindRejectingThePermanentKeyIsNotRetriedOnATimer {
    [self loseTempKey];
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0]);
    if ([_recorder authActionCount] < 1) {
        return;
    }

    [[_recorder authActionAtIndex:0] failWithBindError:[[MTRpcError alloc] initWithErrorCode:400 errorDescription:@"ENCRYPTED_MESSAGE_INVALID"]];

    XCTAssertFalse([_recorder waitForAuthActionCount:2 timeout:4.0], @"a bind that cannot succeed must not be repeated on a timer");
}

// The connection is paused and resumed across the failure, as the app does
// when it goes to background and back.
- (void)testConnectionPausedAcrossAFailedKeyCreationAsksAgainOnResume {
    [self loseTempKey];
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0]);
    if ([_recorder authActionCount] < 1) {
        return;
    }

    [_proto pause];
    [[_recorder authActionAtIndex:0] failWithBindError:[[MTRpcError alloc] initWithErrorCode:500 errorDescription:@"INTERNAL_SERVER_ERROR"]];
    XCTAssertFalse([_recorder waitForAuthActionCount:2 timeout:3.0], @"no connection is active, so nothing needs the key yet");

    [_proto resume];

    XCTAssertTrue([_recorder waitForAuthActionCount:2 timeout:kRetryWindow], @"resuming must ask for the key again");
    if ([_recorder authActionCount] < 2) {
        return;
    }
    [[_recorder authActionAtIndex:1] succeed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return !MTTestIsWaiting(self->_proto); }));
}

@end
