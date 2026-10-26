#import <XCTest/XCTest.h>

#import <stdatomic.h>

#import <MtProtoKit/MTTransport.h>

#import "MTTestSupport.h"

// MTContext.checkIfLoggedOut asks whether the server still knows a
// datacenter's permanent key by creating a temp key and binding it. A bind
// the server rejects with ENCRYPTED_MESSAGE_INVALID means the permanent key is
// gone and the user is logged out. Three defects:
// - the 60 s throttle stored the previous (nil) timestamp, so it never
//   engaged, and every call cancelled the check in flight and started another;
// - any failed bind counted as "key removed", so a transient server error
//   during the check reported a logout;
// - the check's auth action completed at once, without contacting the
//   server, whenever the context held a temp key for the selector (the main
//   session's own key, or a stale copy the Rust engine left after it
//   expired), so it always answered "not removed" and a session terminated
//   from another device never logged out.

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

@interface MTDatacenterAuthAction (MTLoggedOutCheckTestAccess)

- (void)completeWithAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp serverSalt:(int64_t)serverSalt;
- (void)bindAuthKey:(MTDatacenterAuthKey *)authKey persistentAuthInfo:(MTDatacenterAuthInfo *)persistentAuthInfo timestamp:(int64_t)timestamp serverSalt:(int64_t)serverSalt connection:(id)connection;
// What the action does once auth.bindTempAuthKey succeeded.
- (void)completeWithBoundAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp serverSalt:(int64_t)serverSalt;

@end

// The production action up to its bind, which only records the permanent key.
@interface MTTestBindRecordingAuthAction : MTDatacenterAuthAction

@property (nonatomic, readonly) int64_t boundPermanentKeyId;

@end

@implementation MTTestBindRecordingAuthAction

- (void)bindAuthKey:(MTDatacenterAuthKey *)authKey persistentAuthInfo:(MTDatacenterAuthInfo *)persistentAuthInfo timestamp:(int64_t)timestamp serverSalt:(int64_t)serverSalt connection:(id)connection {
    _boundPermanentKeyId = persistentAuthInfo.authKeyId;
    [(MTTransport *)connection stop];
}

@end

// The production action, with its completion observed: whether it finished
// without a key exchange.
@interface MTTestFinishRecordingAuthAction : MTDatacenterAuthAction

@property (nonatomic, readonly) NSInteger finishCount;

@end

@implementation MTTestFinishRecordingAuthAction {
    _Atomic(NSInteger) _finishCount;
}

- (void)complete {
    atomic_fetch_add(&_finishCount, 1);
    [super complete];
}

- (void)fail {
    atomic_fetch_add(&_finishCount, 1);
    [super fail];
}

- (NSInteger)finishCount {
    return atomic_load(&_finishCount);
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

- (void)testTheCheckMakesAFreshKeyItNeverStores {
    [_context checkIfLoggedOut:kDatacenterId];
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0]);
    if ([_recorder authActionCount] < 1) {
        return;
    }

    MTTestAuthAction *action = [_recorder authActionAtIndex:0];
    XCTAssertEqual(action.selector, MTDatacenterAuthInfoSelectorEphemeralMain);
    XCTAssertTrue(action.replacesExistingKey, @"a temp key the context holds must not answer the check");
    XCTAssertNotNil(action.probedPermanentKey, @"the check's key must never replace the one the sessions use");
    XCTAssertEqual(action.probedPermanentKey.authKeyId, [_context authInfoForDatacenterWithId:kDatacenterId selector:MTDatacenterAuthInfoSelectorPersistent].authKeyId, @"it binds to the key the check is about");
}

// The permanent key can change while the check's key exchange runs; the check
// binds to the key it is about, which is the one its verdict is compared with.
- (void)testTheCheckBindsTheKeyItIsAbout {
    MTTestSetAddress(_context, kDatacenterId, false);
    MTDatacenterAuthInfo *probed = [_context authInfoForDatacenterWithId:kDatacenterId selector:MTDatacenterAuthInfoSelectorPersistent];
    MTTestBindRecordingAuthAction *action = [[MTTestBindRecordingAuthAction alloc] initWithAuthKeyInfoSelector:MTDatacenterAuthInfoSelectorEphemeralMain isCdn:false skipBind:false completion:^(__unused MTDatacenterAuthAction *action, __unused bool success) {
    }];
    action.replacesExistingKey = true;
    action.probedPermanentKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:probed.authKey authKeyId:probed.authKeyId validUntilTimestamp:probed.validUntilTimestamp notBound:false];
    [action execute:_context datacenterId:kDatacenterId];

    [_context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
    MTDatacenterAuthInfo *made = MTTestMakeAuthInfo();
    [action completeWithAuthKey:[[MTDatacenterAuthKey alloc] initWithAuthKey:made.authKey authKeyId:made.authKeyId validUntilTimestamp:INT32_MAX notBound:false] timestamp:0 serverSalt:0];

    XCTAssertEqual(action.boundPermanentKeyId, probed.authKeyId);
    [action cancel];
}

// Runs the production action up to a successful auth.bindTempAuthKey and
// reports the session's temp key, the temp key the context holds afterwards,
// and whether the action succeeded.
- (void)bindSucceedsProbing:(bool)probing sessionsKeyId:(int64_t *)sessionsKeyId keptKeyId:(int64_t *)keptKeyId boundKeyId:(int64_t *)boundKeyId succeeded:(bool *)succeeded {
    MTTestSetAddress(_context, kDatacenterId, false);
    MTDatacenterAuthInfo *sessionsKey = MTTestMakeAuthInfo();
    [_context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:sessionsKey selector:MTDatacenterAuthInfoSelectorEphemeralMain];
    MTDatacenterAuthInfo *probed = [_context authInfoForDatacenterWithId:kDatacenterId selector:MTDatacenterAuthInfoSelectorPersistent];
    __block bool result = false;
    MTDatacenterAuthAction *action = [[MTDatacenterAuthAction alloc] initWithAuthKeyInfoSelector:MTDatacenterAuthInfoSelectorEphemeralMain isCdn:false skipBind:false completion:^(__unused MTDatacenterAuthAction *action, bool success) {
        result = success;
    }];
    action.replacesExistingKey = true;
    if (probing) {
        action.probedPermanentKey = [[MTDatacenterAuthKey alloc] initWithAuthKey:probed.authKey authKeyId:probed.authKeyId validUntilTimestamp:probed.validUntilTimestamp notBound:false];
    }
    [action execute:_context datacenterId:kDatacenterId];

    MTDatacenterAuthInfo *made = MTTestMakeAuthInfo();
    [action completeWithBoundAuthKey:[[MTDatacenterAuthKey alloc] initWithAuthKey:made.authKey authKeyId:made.authKeyId validUntilTimestamp:INT32_MAX notBound:false] timestamp:0 serverSalt:0];
    [action cancel];

    *sessionsKeyId = sessionsKey.authKeyId;
    *keptKeyId = [_context authInfoForDatacenterWithId:kDatacenterId selector:MTDatacenterAuthInfoSelectorEphemeralMain].authKeyId;
    *boundKeyId = made.authKeyId;
    *succeeded = result;
}

// The check's bind succeeded: the server knows the permanent key. The check's
// key must not replace the one the sessions use (an ordinary action does).
- (void)testACheckWhoseBindSucceedsStoresNothing {
    int64_t sessionsKeyId = 0;
    int64_t keptKeyId = 0;
    int64_t boundKeyId = 0;
    bool succeeded = false;

    [self bindSucceedsProbing:true sessionsKeyId:&sessionsKeyId keptKeyId:&keptKeyId boundKeyId:&boundKeyId succeeded:&succeeded];
    XCTAssertTrue(succeeded);
    XCTAssertEqual(keptKeyId, sessionsKeyId);

    [self bindSucceedsProbing:false sessionsKeyId:&sessionsKeyId keptKeyId:&keptKeyId boundKeyId:&boundKeyId succeeded:&succeeded];
    XCTAssertTrue(succeeded);
    XCTAssertEqual(keptKeyId, boundKeyId, @"the control: an ordinary action stores the key it bound");
}

// A probe that never ends is given up without a verdict, so its connection
// does not keep the context alive.
- (void)testACheckThatNeverEndsIsGivenUp {
    _context.loggedOutCheckTimeout = 0.5;
    [_context checkIfLoggedOut:kDatacenterId];
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0]);
    if ([_recorder authActionCount] < 1) {
        return;
    }

    MTTestAuthAction *action = [_recorder authActionAtIndex:0];
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return action.wasCancelled; }));
    XCTAssertEqual(_listener.logoutCount, 0);
}

// The Rust engine keeps copies of its bound temp keys in the context, and a
// copy stays after it expired (the app was closed past its end). With the
// production action, such a copy used to answer the check at once.
- (void)testAStoredTemporaryKeyDoesNotAnswerTheCheck {
    MTTestSetAddress(_context, kDatacenterId, false);
    MTDatacenterAuthInfo *persistent = [_context authInfoForDatacenterWithId:kDatacenterId selector:MTDatacenterAuthInfoSelectorPersistent];
    MTDatacenterAuthInfo *made = MTTestMakeAuthInfo();
    MTDatacenterAuthInfo *expiredCopy = [[MTDatacenterAuthInfo alloc] initWithAuthKey:made.authKey authKeyId:made.authKeyId validUntilTimestamp:(int32_t)[NSDate date].timeIntervalSince1970 - 3600 saltSet:made.saltSet authKeyAttributes:@{@"rustEngineBoundTo": @(persistent.authKeyId)}];
    [_context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:expiredCopy selector:MTDatacenterAuthInfoSelectorEphemeralMain];

    __block MTTestFinishRecordingAuthAction *action = nil;
    _context.authActionFactory = ^MTDatacenterAuthAction *(MTDatacenterAuthInfoSelector selector, bool isCdn, bool skipBind, void (^completion)(MTDatacenterAuthAction *, bool)) {
        MTTestFinishRecordingAuthAction *recording = [[MTTestFinishRecordingAuthAction alloc] initWithAuthKeyInfoSelector:selector isCdn:isCdn skipBind:skipBind completion:completion];
        action = recording;
        return recording;
    };

    [_context checkIfLoggedOut:kDatacenterId];
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return action != nil; }));

    XCTAssertFalse(MTTestWaitUntil(1.5, ^bool{ return action.finishCount != 0; }), @"the check must reach the server, not finish on the stored copy");
    XCTAssertEqual([_context authInfoForDatacenterWithId:kDatacenterId selector:MTDatacenterAuthInfoSelectorEphemeralMain].authKeyId, expiredCopy.authKeyId);
    XCTAssertEqual(_listener.logoutCount, 0);
    [action cancel];
}

// A probe that never gets an answer (no route, a silent server) is not a
// logout, and a second check within the throttle window does not start
// another one.
- (void)testASilentCheckIsNotALogout {
    [_context checkIfLoggedOut:kDatacenterId];
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0]);

    [_context checkIfLoggedOut:kDatacenterId];

    XCTAssertFalse(MTTestWaitUntil(2.0, ^bool{ return self->_listener.logoutCount != 0; }));
    XCTAssertEqual([_recorder authActionCount], 1u);
}

// The session's own binds were refused (or a refusal was forged), but the
// check's fresh key binds: the server still knows the permanent key.
- (void)testACheckWhoseBindSucceedsIsNotALogout {
    [_context checkIfLoggedOut:kDatacenterId];
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0]);
    if ([_recorder authActionCount] < 1) {
        return;
    }

    [[_recorder authActionAtIndex:0] complete];

    XCTAssertFalse(MTTestWaitUntil(1.0, ^bool{ return self->_listener.logoutCount != 0; }));
}

- (void)testARefusalAboutAReplacedPermanentKeyIsNotALogout {
    [_context checkIfLoggedOut:kDatacenterId];
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0]);
    if ([_recorder authActionCount] < 1) {
        return;
    }

    [_context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:MTTestMakeAuthInfo() selector:MTDatacenterAuthInfoSelectorPersistent];
    [[_recorder authActionAtIndex:0] failWithBindError:[[MTRpcError alloc] initWithErrorCode:400 errorDescription:@"ENCRYPTED_MESSAGE_INVALID"]];

    XCTAssertFalse(MTTestWaitUntil(1.0, ^bool{ return self->_listener.logoutCount != 0; }), @"the verdict was about a key the context no longer uses");
}

- (void)testBindErrorClassification {
    XCTAssertTrue([MTDatacenterAuthAction bindErrorMeansPermanentKeyIsUnknown:[[MTRpcError alloc] initWithErrorCode:400 errorDescription:@"ENCRYPTED_MESSAGE_INVALID"]]);
    XCTAssertFalse([MTDatacenterAuthAction bindErrorMeansPermanentKeyIsUnknown:[[MTRpcError alloc] initWithErrorCode:500 errorDescription:@"INTERNAL_SERVER_ERROR"]]);
    XCTAssertFalse([MTDatacenterAuthAction bindErrorMeansPermanentKeyIsUnknown:[[MTRpcError alloc] initWithErrorCode:400 errorDescription:@"TEMP_AUTH_KEY_EMPTY"]]);
    XCTAssertFalse([MTDatacenterAuthAction bindErrorMeansPermanentKeyIsUnknown:nil], @"a bind answered with boolFalse carries no error");
}

@end
