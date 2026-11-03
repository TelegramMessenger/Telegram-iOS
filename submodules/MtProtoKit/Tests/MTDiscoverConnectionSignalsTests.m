#import <XCTest/XCTest.h>

#import <MtProtoKit/MTSignal.h>
#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTDisposable.h>
#import <MtProtoKit/MTAtomic.h>
#import <MtProtoKit/MTApiEnvironment.h>
#import <MtProtoKit/MTDatacenterAddress.h>

#import "MTDiscoverConnectionSignals.h"

// Scheme discovery used to re-probe every datacenter address every second, through the
// proxy, for as long as nothing answered. Through an unreachable proxy that never ends, and
// every probe opened a connection (bugs.telegram.org/c/64534). These pin the two changes:
// the retry cadence backs off, and under a proxy the probe list is cut down to what can
// actually tell one outcome from another.

static MTDatacenterAddress *makeAddressWithMedia(NSString *ip, uint16_t port, bool preferForMedia, bool preferForProxy) {
    return [[MTDatacenterAddress alloc] initWithIp:ip port:port preferForMedia:preferForMedia restrictToTcp:false cdn:false preferForProxy:preferForProxy secret:nil];
}

static MTDatacenterAddress *makeAddress(NSString *ip, uint16_t port, bool preferForProxy) {
    return makeAddressWithMedia(ip, port, false, preferForProxy);
}

static MTSocksProxySettings *makeSocksProxy(void) {
    return [[MTSocksProxySettings alloc] initWithIp:@"proxy.example.org" port:1080 username:nil password:nil secret:nil];
}

static MTSocksProxySettings *makeMtProxy(void) {
    NSMutableData *secret = [[NSMutableData alloc] initWithLength:16];
    return [[MTSocksProxySettings alloc] initWithIp:@"proxy.example.org" port:443 username:nil password:nil secret:secret];
}

static MTSocksProxySettings *makeWebProxy(void) {
    NSMutableData *secret = [[NSMutableData alloc] initWithLength:16];
    return [[MTSocksProxySettings alloc] initWithIp:@"relay.example.org" port:443 username:nil password:nil secret:secret webProxy:true];
}

@interface MTDiscoverConnectionSignalsTests : XCTestCase
@end

@implementation MTDiscoverConnectionSignalsTests

#pragma mark - Probe list under a proxy

- (void)testWithoutProxyEveryAddressAndAlternatePortIsProbed {
    NSArray *list = @[
        makeAddress(@"149.154.175.50", 443, false),
        makeAddress(@"149.154.167.50", 443, false),
        makeAddress(@"2001:b28:f23d:f001::a", 443, false),
    ];

    NSArray *result = [MTDiscoverConnectionSignals probeAddressesForAddressList:list media:false isProxy:false proxySettings:nil];
    XCTAssertEqual(result.count, 3u);

    NSArray *ports = [MTDiscoverConnectionSignals alternatePortsForProxySettings:nil];
    XCTAssertEqualObjects(ports, (@[@80, @5222]));
}

- (void)testSocksProxyKeepsAddressesButSkipsAlternatePorts {
    // SOCKS5 forwards to the address it is given, so the addresses still tell outcomes
    // apart; the alternate ports exist to dodge local port filtering, which a proxy
    // already does.
    NSArray *list = @[
        makeAddress(@"149.154.175.50", 443, true),
        makeAddress(@"149.154.167.50", 443, true),
        makeAddress(@"149.154.175.100", 443, false),
    ];
    MTSocksProxySettings *settings = makeSocksProxy();

    NSArray *result = [MTDiscoverConnectionSignals probeAddressesForAddressList:list media:false isProxy:true proxySettings:settings];
    XCTAssertEqual(result.count, 2u);

    NSArray *ports = [MTDiscoverConnectionSignals alternatePortsForProxySettings:settings];
    XCTAssertEqual(ports.count, 0u);
}

- (void)testMtProxyCollapsesToOneIpv4Address {
    // An MTProxy picks the datacenter from the obfuscated header and ignores the address,
    // so N probes through it carry exactly the information of one.
    NSArray *list = @[
        makeAddress(@"2001:b28:f23d:f001::a", 443, true),
        makeAddress(@"149.154.175.50", 443, true),
        makeAddress(@"149.154.167.50", 443, true),
    ];
    MTSocksProxySettings *settings = makeMtProxy();

    NSArray<MTDatacenterAddress *> *result = [MTDiscoverConnectionSignals probeAddressesForAddressList:list media:false isProxy:true proxySettings:settings];
    XCTAssertEqual(result.count, 1u);
    XCTAssertEqualObjects(result.firstObject.ip, @"149.154.175.50");

    XCTAssertEqual([MTDiscoverConnectionSignals alternatePortsForProxySettings:settings].count, 0u);
}

- (void)testMtProxyFallsBackToIpv6WhenThatIsAllThereIs {
    NSArray *list = @[
        makeAddress(@"2001:b28:f23d:f001::a", 443, true),
    ];

    NSArray<MTDatacenterAddress *> *result = [MTDiscoverConnectionSignals probeAddressesForAddressList:list media:false isProxy:true proxySettings:makeMtProxy()];
    XCTAssertEqual(result.count, 1u);
    XCTAssertEqualObjects(result.firstObject.ip, @"2001:b28:f23d:f001::a");
}

- (void)testWebProxyCollapsesToOneAddress {
    NSArray *list = @[
        makeAddress(@"149.154.175.50", 443, true),
        makeAddress(@"149.154.167.50", 443, true),
    ];

    NSArray *result = [MTDiscoverConnectionSignals probeAddressesForAddressList:list media:false isProxy:true proxySettings:makeWebProxy()];
    XCTAssertEqual(result.count, 1u);
}

- (void)testProxyWithNoProxyPreferredAddressesFallsBackToWholeList {
    // A datacenter whose config has no `static` address used to produce zero probes under
    // a proxy, and discovery spun on its retry timer forever.
    NSArray *list = @[
        makeAddress(@"149.154.175.50", 443, false),
        makeAddress(@"149.154.167.50", 443, false),
    ];

    NSArray *socksResult = [MTDiscoverConnectionSignals probeAddressesForAddressList:list media:false isProxy:true proxySettings:makeSocksProxy()];
    XCTAssertEqual(socksResult.count, 2u);

    NSArray *mtProxyResult = [MTDiscoverConnectionSignals probeAddressesForAddressList:list media:false isProxy:true proxySettings:makeMtProxy()];
    XCTAssertEqual(mtProxyResult.count, 1u);
}

- (void)testFallbackWithoutProxyPreferenceStillExcludesMediaAddresses {
    // The context drops a media-only address from the schemes of a non-media connection, so
    // a media address winning a non-media probe would be discovery producing nothing usable.
    // The first relaxation therefore keeps the media match. Order matters for the MTProxy
    // collapse, so the media-only address is listed first.
    NSArray *list = @[
        makeAddressWithMedia(@"149.154.175.51", 443, true, false),
        makeAddressWithMedia(@"149.154.175.50", 443, false, false),
        makeAddressWithMedia(@"149.154.167.50", 443, false, false),
    ];

    NSArray<MTDatacenterAddress *> *mtProxyResult = [MTDiscoverConnectionSignals probeAddressesForAddressList:list media:false isProxy:true proxySettings:makeMtProxy()];
    XCTAssertEqual(mtProxyResult.count, 1u);
    XCTAssertEqualObjects(mtProxyResult.firstObject.ip, @"149.154.175.50");

    NSArray<MTDatacenterAddress *> *socksResult = [MTDiscoverConnectionSignals probeAddressesForAddressList:list media:false isProxy:true proxySettings:makeSocksProxy()];
    XCTAssertEqual(socksResult.count, 2u);
    for (MTDatacenterAddress *address in socksResult) {
        XCTAssertFalse(address.preferForMedia);
    }
}

- (void)testFallbackReachesWholeListOnlyWhenMediaMatchIsEmptyToo {
    // Every address is media-only and this is a non-media probe under a proxy: the second
    // stage still yields probes rather than none.
    NSArray *list = @[
        makeAddressWithMedia(@"149.154.175.51", 443, true, false),
    ];

    NSArray *result = [MTDiscoverConnectionSignals probeAddressesForAddressList:list media:false isProxy:true proxySettings:makeSocksProxy()];
    XCTAssertEqual(result.count, 1u);
}

- (void)testEmptyAddressListYieldsNoProbes {
    NSArray *result = [MTDiscoverConnectionSignals probeAddressesForAddressList:@[] media:false isProxy:true proxySettings:makeMtProxy()];
    XCTAssertEqual(result.count, 0u);
}

- (void)testMediaFallbackStillAppliesUnderProxy {
    // Media discovery falls back to the whole list when nothing is media-preferred; that
    // must keep working before the proxy collapse is applied.
    NSArray *list = @[
        makeAddress(@"149.154.175.50", 443, false),
    ];

    NSArray *result = [MTDiscoverConnectionSignals probeAddressesForAddressList:list media:true isProxy:true proxySettings:makeMtProxy()];
    XCTAssertEqual(result.count, 1u);
}

#pragma mark - Retry backoff

- (MTSignal *)roundRecordingInto:(NSMutableArray<NSNumber *> *)starts lock:(NSLock *)lock emitAfter:(NSInteger)emitAfterRounds {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        NSUInteger count = 0;
        [lock lock];
        [starts addObject:@(CFAbsoluteTimeGetCurrent())];
        count = starts.count;
        [lock unlock];
        if (emitAfterRounds > 0 && (NSInteger)count >= emitAfterRounds) {
            [subscriber putNext:@"scheme"];
        }
        [subscriber putCompletion];
        return nil;
    }];
}

- (void)testBackoffGrowsBetweenRoundsAndCaps {
    NSMutableArray<NSNumber *> *starts = [[NSMutableArray alloc] init];
    NSLock *lock = [[NSLock alloc] init];
    MTSignal *round = [self roundRecordingInto:starts lock:lock emitAfter:0];

    // Expected starts at roughly 0, .05, .15, .35, .55, .75, .95, 1.15 s. A fixed 50 ms
    // cadence would produce ~26 rounds in the same window.
    id<MTDisposable> disposable = [[MTDiscoverConnectionSignals repeatSignal:round withBackoffFrom:0.05 upTo:0.2 onQueue:[MTQueue concurrentDefaultQueue]] startWithNext:^(__unused id next) {
    }];
    [NSThread sleepForTimeInterval:1.3];
    [disposable dispose];

    [lock lock];
    NSArray<NSNumber *> *recorded = [starts copy];
    [lock unlock];

    XCTAssertGreaterThanOrEqual(recorded.count, 6u);
    XCTAssertLessThanOrEqual(recorded.count, 9u);

    NSMutableArray<NSNumber *> *gaps = [[NSMutableArray alloc] init];
    for (NSUInteger i = 1; i < recorded.count; i++) {
        [gaps addObject:@(recorded[i].doubleValue - recorded[i - 1].doubleValue)];
    }
    XCTAssertGreaterThanOrEqual(gaps.count, 4u);

    // Assert the shape rather than exact durations: timers on the concurrent queue jitter
    // by tens of milliseconds on a loaded simulator, and the round count above already
    // rules out a fixed cadence.
    XCTAssertLessThan(gaps[0].doubleValue, 0.1, @"first pause should be near the initial 50 ms");
    XCTAssertGreaterThanOrEqual(gaps[1].doubleValue, gaps[0].doubleValue, @"second pause should not be shorter than the first");
    XCTAssertLessThan(gaps[1].doubleValue, 0.2, @"second pause should be near 100 ms, below the cap");
    for (NSUInteger i = 2; i < gaps.count; i++) {
        XCTAssertGreaterThanOrEqual(gaps[i].doubleValue, 0.15, @"gap %lu should have reached the cap", (unsigned long)i);
        XCTAssertLessThanOrEqual(gaps[i].doubleValue, 0.4, @"gap %lu should not exceed the cap", (unsigned long)i);
    }
}

- (void)testBackoffStopsAtFirstValueWhenTakenOnce {
    NSMutableArray<NSNumber *> *starts = [[NSMutableArray alloc] init];
    NSLock *lock = [[NSLock alloc] init];
    MTSignal *round = [self roundRecordingInto:starts lock:lock emitAfter:3];

    __block id received = nil;
    __block bool completed = false;
    id<MTDisposable> disposable = [[[MTDiscoverConnectionSignals repeatSignal:round withBackoffFrom:0.01 upTo:0.05 onQueue:[MTQueue concurrentDefaultQueue]] take:1] startWithNext:^(id next) {
        received = next;
    } error:^(__unused id error) {
    } completed:^{
        completed = true;
    }];
    [NSThread sleepForTimeInterval:0.5];

    [lock lock];
    NSUInteger count = starts.count;
    [lock unlock];

    XCTAssertEqual(count, 3u);
    XCTAssertEqualObjects(received, @"scheme");
    XCTAssertTrue(completed);
    [disposable dispose];
}

- (void)testDisposingDuringTheDelayStopsFurtherRounds {
    NSMutableArray<NSNumber *> *starts = [[NSMutableArray alloc] init];
    NSLock *lock = [[NSLock alloc] init];
    MTSignal *round = [self roundRecordingInto:starts lock:lock emitAfter:0];

    id<MTDisposable> disposable = [[MTDiscoverConnectionSignals repeatSignal:round withBackoffFrom:0.1 upTo:0.1 onQueue:[MTQueue concurrentDefaultQueue]] startWithNext:^(__unused id next) {
    }];
    [NSThread sleepForTimeInterval:0.03];
    [disposable dispose];
    [NSThread sleepForTimeInterval:0.4];

    [lock lock];
    NSUInteger count = starts.count;
    [lock unlock];

    XCTAssertEqual(count, 1u);
}

@end
