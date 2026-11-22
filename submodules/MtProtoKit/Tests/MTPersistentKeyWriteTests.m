#import <XCTest/XCTest.h>

#import <stdatomic.h>

#import "MTTestSupport.h"

// MTDatacenterAuthAction writes the permanent key it made when its handshake
// ends. It never looked at what the context held by then, so a key that
// appeared meanwhile (another maker, a restored backup) was overwritten, and
// the sessions already running under it ended up with a key the account is
// not authorized with (AUTH_KEY_UNREGISTERED, a logout). MTContext keeps one
// action per datacenter, but that does not cover keys written outside it.

static const NSInteger kDatacenterId = 2;

@interface MTDatacenterAuthAction (MTPersistentKeyWriteTestAccess)

// What the handshake calls when the key exchange finished.
- (void)completeWithAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp serverSalt:(int64_t)serverSalt;

@end

@interface MTTestSuccessCounter : NSObject

@property (nonatomic, readonly) NSInteger value;

- (void)increment;

@end

@implementation MTTestSuccessCounter {
    _Atomic(NSInteger) _value;
}

- (void)increment {
    atomic_fetch_add(&_value, 1);
}

- (NSInteger)value {
    return atomic_load(&_value);
}

@end

@interface MTPersistentKeyWriteTests : XCTestCase
@end

@implementation MTPersistentKeyWriteTests {
    MTContext *_context;
    NSMutableArray<MTDatacenterAuthAction *> *_actions;
}

- (void)setUp {
    [super setUp];
    _context = MTTestMakeContext(true);
    MTTestSetAddress(_context, kDatacenterId, false);
    _actions = [[NSMutableArray alloc] init];
}

- (void)tearDown {
    for (MTDatacenterAuthAction *action in _actions) {
        [action cancel];
    }
    _context = nil;
    [super tearDown];
}

- (MTDatacenterAuthAction *)startActionCountingSuccessIn:(MTTestSuccessCounter *)successes {
    MTDatacenterAuthAction *action = [[MTDatacenterAuthAction alloc] initWithAuthKeyInfoSelector:MTDatacenterAuthInfoSelectorPersistent isCdn:false skipBind:false completion:^(__unused MTDatacenterAuthAction *action, bool success) {
        if (success) {
            [successes increment];
        }
    }];
    [_actions addObject:action];
    [action execute:_context datacenterId:kDatacenterId];
    return action;
}

- (MTDatacenterAuthKey *)makeKey {
    MTDatacenterAuthInfo *info = MTTestMakeAuthInfo();
    return [[MTDatacenterAuthKey alloc] initWithAuthKey:info.authKey authKeyId:info.authKeyId validUntilTimestamp:INT32_MAX notBound:false];
}

- (int64_t)storedKeyId {
    return [_context authInfoForDatacenterWithId:kDatacenterId selector:MTDatacenterAuthInfoSelectorPersistent].authKeyId;
}

- (void)testTheKeyIsStoredWhenTheContextHasNone {
    MTTestSuccessCounter *successes = [[MTTestSuccessCounter alloc] init];
    MTDatacenterAuthAction *action = [self startActionCountingSuccessIn:successes];
    MTDatacenterAuthKey *key = [self makeKey];

    [action completeWithAuthKey:key timestamp:0 serverSalt:1];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return successes.value == 1; }));
    XCTAssertEqual([self storedKeyId], key.authKeyId);
}

- (void)testAKeyThatAppearedMeanwhileIsNotReplaced {
    MTTestSuccessCounter *successes = [[MTTestSuccessCounter alloc] init];
    MTDatacenterAuthAction *action = [self startActionCountingSuccessIn:successes];
    MTDatacenterAuthInfo *existing = MTTestMakeAuthInfo();
    [_context updateAuthInfoForDatacenterWithId:kDatacenterId authInfo:existing selector:MTDatacenterAuthInfoSelectorPersistent];

    [action completeWithAuthKey:[self makeKey] timestamp:0 serverSalt:1];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return successes.value == 1; }), @"the action still completes: the datacenter has a permanent key");
    XCTAssertEqual([self storedKeyId], existing.authKeyId);
}

- (void)testOfTwoActionsTheFirstToFinishKeepsItsKey {
    MTTestSuccessCounter *successes = [[MTTestSuccessCounter alloc] init];
    MTDatacenterAuthAction *first = [self startActionCountingSuccessIn:successes];
    MTDatacenterAuthAction *second = [self startActionCountingSuccessIn:successes];
    MTDatacenterAuthKey *firstKey = [self makeKey];
    MTDatacenterAuthKey *secondKey = [self makeKey];

    [second completeWithAuthKey:secondKey timestamp:0 serverSalt:1];
    [first completeWithAuthKey:firstKey timestamp:0 serverSalt:1];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return successes.value == 2; }));
    XCTAssertEqual([self storedKeyId], secondKey.authKeyId);
}

// The context runs one action per datacenter and selector and tells the
// sessions waiting for the key once it is stored, so the key must be in the
// context by the time the context hears that its action finished.
- (void)testTheContextSeesTheKeyWhenItsActionFinishes {
    __block MTDatacenterAuthAction *action = nil;
    __block int64_t keyIdWhenFinished = 0;
    MTContext *context = _context;
    NSMutableArray<MTDatacenterAuthAction *> *actions = _actions;
    _context.authActionFactory = ^MTDatacenterAuthAction *(MTDatacenterAuthInfoSelector selector, bool isCdn, bool skipBind, void (^completion)(MTDatacenterAuthAction *, bool)) {
        MTDatacenterAuthAction *made = [[MTDatacenterAuthAction alloc] initWithAuthKeyInfoSelector:selector isCdn:isCdn skipBind:skipBind completion:^(MTDatacenterAuthAction *finished, bool success) {
            keyIdWhenFinished = [context authInfoForDatacenterWithId:kDatacenterId selector:MTDatacenterAuthInfoSelectorPersistent].authKeyId;
            completion(finished, success);
        }];
        [actions addObject:made];
        action = made;
        return made;
    };
    [_context authInfoForDatacenterWithIdRequired:kDatacenterId isCdn:false selector:MTDatacenterAuthInfoSelectorPersistent allowUnboundEphemeralKeys:false];
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return action != nil; }));
    MTDatacenterAuthKey *key = [self makeKey];

    [action completeWithAuthKey:key timestamp:0 serverSalt:1];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return keyIdWhenFinished != 0; }));
    XCTAssertEqual(keyIdWhenFinished, key.authKeyId);
    _context.authActionFactory = nil;
}

@end
