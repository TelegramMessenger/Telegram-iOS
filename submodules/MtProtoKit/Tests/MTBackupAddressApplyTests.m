#import <XCTest/XCTest.h>

#import <os/lock.h>

#import <MtProtoKit/MTBackupAddressSignals.h>
#import <MtProtoKit/MTDatacenterAddress.h>
#import <MtProtoKit/MTDatacenterAddressSet.h>

#import "MTTestSupport.h"

// A backup address fetch (getConfig through a backup IP) used to compare the
// fetched address lists against the throwaway context it had just built for
// the fetch, which knows no addresses. Every datacenter therefore looked
// changed, and each one was applied with forceUpdateSchemes, which resets the
// transport of every connection to it. In the field log all seven fetches
// "updated" all five datacenters with identical lists, and one of them cut
// the DC 2 token transfer off mid-request. A fetch must only touch the
// datacenters whose addresses actually changed, judged against the real
// context.

@interface MTTestSchemeResetListener : NSObject <MTContextChangeListener>

- (NSArray<NSNumber *> *)resetDatacenterIds;

@end

@implementation MTTestSchemeResetListener {
    os_unfair_lock _lock;
    NSMutableArray<NSNumber *> *_resetDatacenterIds;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _resetDatacenterIds = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)contextDatacenterTransportSchemesUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId shouldReset:(bool)shouldReset {
    if (!shouldReset) {
        return;
    }
    os_unfair_lock_lock(&_lock);
    [_resetDatacenterIds addObject:@(datacenterId)];
    os_unfair_lock_unlock(&_lock);
}

- (NSArray<NSNumber *> *)resetDatacenterIds {
    os_unfair_lock_lock(&_lock);
    NSArray<NSNumber *> *result = [_resetDatacenterIds copy];
    os_unfair_lock_unlock(&_lock);
    return result;
}

@end

@interface MTBackupAddressApplyTests : XCTestCase
@end

@implementation MTBackupAddressApplyTests {
    MTContext *_context;
    MTTestSchemeResetListener *_listener;
    NSArray *_dc1List;
    NSArray *_dc2List;
}

- (void)setUp {
    [super setUp];
    _context = MTTestMakeContext(false);
    _dc1List = @[[[MTDatacenterAddress alloc] initWithIp:@"149.154.175.50" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil]];
    _dc2List = @[
        [[MTDatacenterAddress alloc] initWithIp:@"149.154.167.41" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil],
        [[MTDatacenterAddress alloc] initWithIp:@"149.154.167.222" port:443 preferForMedia:true restrictToTcp:false cdn:false preferForProxy:false secret:nil],
    ];
    [_context updateAddressSetForDatacenterWithId:1 addressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:_dc1List] forceUpdateSchemes:false];
    [_context updateAddressSetForDatacenterWithId:2 addressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:_dc2List] forceUpdateSchemes:false];

    _listener = [[MTTestSchemeResetListener alloc] init];
    [_context addChangeListener:_listener];
    // Let the setup's own notifications drain before counting.
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{
        return [self->_context addressSetForDatacenterWithId:2].addressList.count == 2;
    }));
    MTTestWaitUntil(0.2, ^bool{ return false; });
}

- (void)tearDown {
    [_context removeChangeListener:_listener];
    _context = nil;
    [super tearDown];
}

- (void)testUnchangedAddressListsResetNothing {
    bool updated = [MTBackupAddressSignals applyAddressList:@{@1: _dc1List, @2: _dc2List} toContext:_context];

    XCTAssertFalse(updated);
    XCTAssertFalse(MTTestWaitUntil(1.0, ^bool{ return self->_listener.resetDatacenterIds.count != 0; }), @"identical addresses must not reset any connection");
}

- (void)testOnlyTheChangedDatacenterIsReset {
    NSArray *newDc2List = @[[[MTDatacenterAddress alloc] initWithIp:@"149.154.167.35" port:443 preferForMedia:true restrictToTcp:false cdn:false preferForProxy:false secret:nil]];

    bool updated = [MTBackupAddressSignals applyAddressList:@{@1: _dc1List, @2: newDc2List} toContext:_context];

    XCTAssertTrue(updated);
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return [self->_listener.resetDatacenterIds containsObject:@2]; }), @"the changed datacenter's connections must reset onto the new addresses");
    XCTAssertFalse([_listener.resetDatacenterIds containsObject:@1], @"an unchanged datacenter must be left alone");
    XCTAssertEqualObjects([_context addressSetForDatacenterWithId:2].addressList, newDc2List);
}

- (void)testUnknownDatacenterIsAdded {
    NSArray *dc5List = @[[[MTDatacenterAddress alloc] initWithIp:@"91.108.56.188" port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil]];

    bool updated = [MTBackupAddressSignals applyAddressList:@{@5: dc5List} toContext:_context];

    XCTAssertTrue(updated);
    XCTAssertTrue(MTTestWaitUntil(5.0, ^bool{ return [self->_context addressSetForDatacenterWithId:5].addressList.count == 1; }));
}

@end
