#import <XCTest/XCTest.h>

#import <os/lock.h>

#import <MtProtoKit/MTDatacenterAddressSet.h>

#import "MTDiscoverDatacenterAddressAction.h"
#import "MTTestSupport.h"

// MTDiscoverDatacenterAddressAction finds the addresses of a datacenter the
// context knows nothing about by asking another, known datacenter (getConfig).
// Two ways it could hang or give up for good:
// - when the source datacenter had no permanent key yet, it requested one and
//   waited for contextDatacenterAuthInfoUpdated, but never registered as a
//   context listener, so the notification never came;
// - when getConfig failed, it gave up instead of asking the next known
//   datacenter.

@interface MTDiscoverDatacenterAddressAction (MTTestAccess)

- (void)askForAnAddressDatacenterWithId:(NSInteger)targetDatacenterId useTempAuthKeys:(bool)useTempAuthKeys;
- (void)getConfigFailed;

@end

// Records which datacenter the action asks. Calls go through to the real
// implementation only while passThrough is set, so no test reaches the network.
@interface MTTestDiscoverAction : MTDiscoverDatacenterAddressAction <MTDiscoverDatacenterAddressActionDelegate>

@property (nonatomic) bool passThrough;
@property (nonatomic, readonly) bool finished;

- (NSArray<NSNumber *> *)askedDatacenterIds;

@end

@implementation MTTestDiscoverAction {
    os_unfair_lock _lock;
    NSMutableArray<NSNumber *> *_askedDatacenterIds;
    bool _finished;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _askedDatacenterIds = [[NSMutableArray alloc] init];
        self.delegate = self;
    }
    return self;
}

- (void)askForAnAddressDatacenterWithId:(NSInteger)targetDatacenterId useTempAuthKeys:(bool)useTempAuthKeys {
    os_unfair_lock_lock(&_lock);
    [_askedDatacenterIds addObject:@(targetDatacenterId)];
    bool passThrough = _passThrough;
    os_unfair_lock_unlock(&_lock);
    if (passThrough) {
        [super askForAnAddressDatacenterWithId:targetDatacenterId useTempAuthKeys:useTempAuthKeys];
    }
}

- (void)discoverDatacenterAddressActionCompleted:(MTDiscoverDatacenterAddressAction *)action {
    os_unfair_lock_lock(&_lock);
    _finished = true;
    os_unfair_lock_unlock(&_lock);
}

- (NSArray<NSNumber *> *)askedDatacenterIds {
    os_unfair_lock_lock(&_lock);
    NSArray<NSNumber *> *result = [_askedDatacenterIds copy];
    os_unfair_lock_unlock(&_lock);
    return result;
}

- (bool)finished {
    os_unfair_lock_lock(&_lock);
    bool result = _finished;
    os_unfair_lock_unlock(&_lock);
    return result;
}

@end

static const NSInteger kUnknownDatacenterId = 7;

@interface MTDiscoverDatacenterAddressActionTests : XCTestCase
@end

@implementation MTDiscoverDatacenterAddressActionTests {
    MTContext *_context;
    MTTestActionRecorder *_recorder;
    MTTestDiscoverAction *_action;
}

- (void)setUp {
    [super setUp];
    _context = MTTestMakeContext(false);
    _recorder = [[MTTestActionRecorder alloc] initWithContext:_context];
    _action = [[MTTestDiscoverAction alloc] init];
}

- (void)tearDown {
    [_action cancel];
    _action = nil;
    _context.authActionFactory = nil;
    _context.transferAuthActionFactory = nil;
    _context = nil;
    [super tearDown];
}

- (void)waitForAddressSet:(NSInteger)datacenterId {
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{
        return [self->_context addressSetForDatacenterWithId:datacenterId] != nil;
    }));
}

- (void)testDiscoveryContinuesOnceTheSourceDatacenterHasAKey {
    MTTestSetAddress(_context, 1, false);
    [self waitForAddressSet:1];

    _action.passThrough = true;
    [_action execute:_context datacenterId:kUnknownDatacenterId];
    _action.passThrough = false;

    XCTAssertEqualObjects(_action.askedDatacenterIds, @[@1]);
    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0], @"DC 1 has no permanent key yet, so the action asks for one");
    if ([_recorder authActionCount] < 1) {
        return;
    }
    XCTAssertEqual([_recorder authActionAtIndex:0].selector, MTDatacenterAuthInfoSelectorPersistent);

    [[_recorder authActionAtIndex:0] succeed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return self->_action.askedDatacenterIds.count == 2; }), @"once DC 1 has a key the action must ask it for the addresses");
    XCTAssertEqualObjects(_action.askedDatacenterIds.lastObject, @1);
    XCTAssertFalse(_action.finished);
}

- (void)testFailedAttemptAsksTheNextKnownDatacenter {
    MTTestSetAddress(_context, 1, false);
    MTTestSetAddress(_context, 3, false);
    [self waitForAddressSet:1];
    [self waitForAddressSet:3];

    [_action execute:_context datacenterId:kUnknownDatacenterId];
    XCTAssertEqual(_action.askedDatacenterIds.count, 1u);
    NSNumber *first = _action.askedDatacenterIds.firstObject;

    [_action getConfigFailed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return self->_action.askedDatacenterIds.count == 2; }), @"a failed getConfig must move on to the next known datacenter");
    if (_action.askedDatacenterIds.count < 2) {
        return;
    }
    NSNumber *second = _action.askedDatacenterIds[1];
    XCTAssertNotEqualObjects(first, second);
    XCTAssertFalse(_action.finished);

    [_action getConfigFailed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return self->_action.finished; }), @"with every known datacenter tried, the action reports that it is done");
    XCTAssertEqual(_action.askedDatacenterIds.count, 2u);
}

- (void)testFailedKeyRequestForTheSourceDatacenterIsRetried {
    MTTestSetAddress(_context, 1, false);
    [self waitForAddressSet:1];

    _action.passThrough = true;
    [_action execute:_context datacenterId:kUnknownDatacenterId];
    _action.passThrough = false;

    XCTAssertTrue([_recorder waitForAuthActionCount:1 timeout:5.0]);
    if ([_recorder authActionCount] < 1) {
        return;
    }
    [[_recorder authActionAtIndex:0] failWithBindError:nil];

    XCTAssertTrue([_recorder waitForAuthActionCount:2 timeout:10.0], @"the action still needs DC 1's key, so it must ask again");
    if ([_recorder authActionCount] < 2) {
        return;
    }
    XCTAssertEqual([_recorder authActionAtIndex:1].selector, MTDatacenterAuthInfoSelectorPersistent);
    [[_recorder authActionAtIndex:1] succeed];

    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return self->_action.askedDatacenterIds.count == 2; }));
}

@end
