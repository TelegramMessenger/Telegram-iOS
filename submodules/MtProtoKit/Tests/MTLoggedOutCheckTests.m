#import <XCTest/XCTest.h>

#import <stdatomic.h>

#import "MTTestSupport.h"

// MTContext.checkIfLoggedOut asks whether the server still knows a
// datacenter's permanent key by creating a temp key and binding it. A bind
// the server rejects with ENCRYPTED_MESSAGE_INVALID means the permanent key is
// gone and the user is logged out. Two defects:
// - the 60 s throttle stored the previous (nil) timestamp, so it never
//   engaged, and every call cancelled the check in flight and started another;
// - any failed bind counted as "key removed", so a transient server error
//   during the check reported a logout.

static const NSInteger kDatacenterId = 1;

@interface MTTestLogoutListener : NSObject <MTContextChangeListener>

@property (nonatomic, readonly) NSInteger logoutCount;

@end

@implementation MTTestLogoutListener {
    _Atomic(NSInteger) _logoutCount;
}

- (void)contextLoggedOut:(MTContext *)context {
    atomic_fetch_add(&_logoutCount, 1);
}

- (NSInteger)logoutCount {
    return atomic_load(&_logoutCount);
}

@end

@interface MTLoggedOutCheckTests : XCTestCase
@end

@implementation MTLoggedOutCheckTests {
    MTContext *_context;
    MTTestActionRecorder *_recorder;
    MTTestLogoutListener *_listener;
}

- (void)setUp {
    [super setUp];
    _context = MTTestMakeContext(true);
    _recorder = [[MTTestActionRecorder alloc] initWithContext:_context];
    [_context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
    _listener = [[MTTestLogoutListener alloc] init];
    [_context addChangeListener:_listener];
}

- (void)tearDown {
    [_context removeChangeListener:_listener];
    _context.authActionFactory = nil;
    _context.transferAuthActionFactory = nil;
    _context = nil;
    [super tearDown];
}

- (void)testCheckIsThrottled {
    [_context checkIfLoggedOut:kDatacenterId];
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0], @"the check binds a fresh temp key");

    [_context checkIfLoggedOut:kDatacenterId];
    [_context checkIfLoggedOut:kDatacenterId];

    XCTAssertFalse([_recorder waitForAuthActionCount:2 timeout:1.0], @"a second check within 60 s must not restart the one in flight");
}

- (void)testTransientBindFailureIsNotALogout {
    [_context checkIfLoggedOut:kDatacenterId];
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0]);
    if ([_recorder authActionCount] < 1) {
        return;
    }

    [[_recorder authActionAtIndex:0] failWithBindError:[[MTRpcError alloc] initWithErrorCode:500 errorDescription:@"INTERNAL_SERVER_ERROR"]];

    XCTAssertFalse(MTTestWaitUntil(1.0, ^bool{ return self->_listener.logoutCount != 0; }), @"a server error says nothing about the permanent key");
}

- (void)testRejectedPermanentKeyIsALogout {
    [_context checkIfLoggedOut:kDatacenterId];
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0]);
    if ([_recorder authActionCount] < 1) {
        return;
    }

    [[_recorder authActionAtIndex:0] failWithBindError:[[MTRpcError alloc] initWithErrorCode:400 errorDescription:@"ENCRYPTED_MESSAGE_INVALID"]];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return self->_listener.logoutCount == 1; }), @"the server no longer knows the permanent key");
}

- (void)testBindErrorClassification {
    XCTAssertTrue([MTDatacenterAuthAction bindErrorMeansPermanentKeyIsUnknown:[[MTRpcError alloc] initWithErrorCode:400 errorDescription:@"ENCRYPTED_MESSAGE_INVALID"]]);
    XCTAssertFalse([MTDatacenterAuthAction bindErrorMeansPermanentKeyIsUnknown:[[MTRpcError alloc] initWithErrorCode:500 errorDescription:@"INTERNAL_SERVER_ERROR"]]);
    XCTAssertFalse([MTDatacenterAuthAction bindErrorMeansPermanentKeyIsUnknown:[[MTRpcError alloc] initWithErrorCode:400 errorDescription:@"TEMP_AUTH_KEY_EMPTY"]]);
    XCTAssertFalse([MTDatacenterAuthAction bindErrorMeansPermanentKeyIsUnknown:nil], @"a bind answered with boolFalse carries no error");
}

@end
