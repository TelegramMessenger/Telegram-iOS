#import <XCTest/XCTest.h>

#import <QuartzCore/QuartzCore.h>

#import "IDPrivateUIKit.h"
#import "IDVerticalAutoscrollInternal.h"

@interface IDVADifferentialTimer :
    NSObject <IDVerticalAutoscrollTimer>
@property(nonatomic, copy) dispatch_block_t callback;
@property(nonatomic, strong) NSMutableArray<NSDate *> *rescheduleDates;
@property(nonatomic) BOOL invalidated;
- (void)fire;
@end

@implementation IDVADifferentialTimer
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _rescheduleDates = [NSMutableArray array];
    }
    return self;
}
- (void)setFireDate:(NSDate *)date {
    [self.rescheduleDates addObject:date];
}
- (void)invalidate {
    self.invalidated = YES;
}
- (void)fire {
    if (!self.invalidated) {
        self.callback();
    }
}
@end

@interface IDVADifferentialTimerFactory : NSObject
@property(nonatomic, strong) NSMutableArray<IDVADifferentialTimer *> *timers;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *intervals;
- (IDVerticalAutoscrollTimerFactory)factory;
@end

@implementation IDVADifferentialTimerFactory
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _timers = [NSMutableArray array];
        _intervals = [NSMutableArray array];
    }
    return self;
}
- (IDVerticalAutoscrollTimerFactory)factory {
    __weak typeof(self) weakSelf = self;
    return ^id<IDVerticalAutoscrollTimer>(
        NSDate *fireDate,
        NSTimeInterval interval,
        dispatch_block_t callback) {
        (void)fireDate;
        IDVADifferentialTimer *timer =
            [IDVADifferentialTimer new];
        timer.callback = callback;
        [weakSelf.timers addObject:timer];
        [weakSelf.intervals addObject:@(interval)];
        return timer;
    };
}
@end

@interface IDVADifferentialTarget :
    NSObject <IDVerticalAutoscrollTarget>
@property(nonatomic, strong) NSMutableArray<NSNumber *> *observedCounts;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *timestamps;
@property(nonatomic, strong, nullable) XCTestExpectation *expectation;
- (void)updateAutoscroll:(id)autoscroll;
@end

@implementation IDVADifferentialTarget
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _observedCounts = [NSMutableArray array];
        _timestamps = [NSMutableArray array];
    }
    return self;
}
- (void)recordCount:(NSUInteger)count {
    [self.observedCounts addObject:@(count)];
    [self.timestamps addObject:@(CACurrentMediaTime())];
    [self.expectation fulfill];
}
- (void)updateAutoscroll:(id)autoscroll {
    NSDictionary *snapshot =
        IDPrivateTestingCopyUIKitAutoscrollSnapshot(autoscroll);
    [self recordCount:[snapshot[@"count"] unsignedIntegerValue]];
}
- (void)updateVerticalAutoscroll:
    (IDVerticalAutoscroll *)autoscroll {
    [self recordCount:autoscroll.count];
}
@end

@interface IDVADifferentialPolicyContainer :
    UIScrollView <IDVerticalAutoscrollContainerPolicy>
@property(nonatomic) BOOL permitsAutoscroll;
- (BOOL)shouldAutoscroll;
@end

@implementation IDVADifferentialPolicyContainer
- (BOOL)shouldAutoscroll {
    return self.permitsAutoscroll;
}
- (BOOL)id_shouldAutoscroll {
    return self.permitsAutoscroll;
}
@end

@interface IDVADifferentialContext : NSObject
@property(nonatomic, strong) id stock;
@property(nonatomic, strong) IDVerticalAutoscroll *mirror;
@property(nonatomic, strong) IDVADifferentialTimerFactory *timerFactory;
@property(nonatomic, strong, nullable) IDVADifferentialTarget *stockTarget;
@property(nonatomic, strong, nullable) IDVADifferentialTarget *mirrorTarget;
@property(nonatomic, strong, nullable) UIScrollView *stockContainer;
@property(nonatomic, strong, nullable) UIScrollView *mirrorContainer;
@end

@implementation IDVADifferentialContext
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _stock = IDPrivateTestingNewUIKitAutoscroll();
        _timerFactory = [IDVADifferentialTimerFactory new];
        _mirror = [[IDVerticalAutoscroll alloc]
            initWithTimerFactory:_timerFactory.factory];
        _stockTarget = [IDVADifferentialTarget new];
        _mirrorTarget = [IDVADifferentialTarget new];
        _stockContainer = [[UIScrollView alloc]
            initWithFrame:CGRectMake(0, 0, 200, 100)];
        _mirrorContainer = [[UIScrollView alloc]
            initWithFrame:CGRectMake(0, 0, 200, 100)];
    }
    return self;
}
- (void)dealloc {
    IDPrivateTestingInvalidateUIKitAutoscroll(_stock);
    [_mirror invalidate];
}
@end

@interface IDVerticalAutoscrollDifferentialTests : XCTestCase
@end

@implementation IDVerticalAutoscrollDifferentialTests

- (NSDictionary<NSString *, id> *)mirrorSnapshot:
    (IDVerticalAutoscroll *)mirror {
    return @{
        @"active": @(mirror.isActive),
        @"targetPresent": @((BOOL)(mirror.target != nil)),
        @"containerPresent":
            @((BOOL)(mirror.id_scrollContainer != nil)),
        @"point": [NSValue valueWithCGPoint:mirror.point],
        @"directions": @(mirror.directions),
        @"repeatInterval": @(mirror.repeatInterval),
        @"count": @(mirror.count),
    };
}

- (void)assertStock:(id)stock
    matchesMirror:(IDVerticalAutoscroll *)mirror
              row:(NSString *)row {
    NSDictionary<NSString *, id> *stockSnapshot =
        IDPrivateTestingCopyUIKitAutoscrollSnapshot(stock);
    NSDictionary<NSString *, id> *mirrorSnapshot =
        [self mirrorSnapshot:mirror];
    for (NSString *key in @[
             @"active",
             @"targetPresent",
             @"containerPresent",
             @"directions",
             @"repeatInterval",
             @"count",
         ]) {
        XCTAssertEqualObjects(
            stockSnapshot[key],
            mirrorSnapshot[key],
            @"row=%@ key=%@ stock=%@ mirror=%@",
            row,
            key,
            stockSnapshot[key],
            mirrorSnapshot[key]);
    }
    XCTAssertTrue(CGPointEqualToPoint(
        [stockSnapshot[@"point"] CGPointValue],
        [mirrorSnapshot[@"point"] CGPointValue]),
        @"row=%@ stockPoint=%@ mirrorPoint=%@",
        row,
        stockSnapshot[@"point"],
        mirrorSnapshot[@"point"]);
}

- (BOOL)startStock:(IDVADifferentialContext *)context
             point:(CGPoint)point
        directions:(NSUInteger)directions
           interval:(NSTimeInterval)interval {
    return IDPrivateTestingStartUIKitAutoscroll(
        context.stock,
        context.stockTarget,
        context.stockContainer,
        point,
        directions,
        interval);
}

- (BOOL)startMirror:(IDVADifferentialContext *)context
              point:(CGPoint)point
         directions:(IDVerticalAutoscrollDirection)directions
            interval:(NSTimeInterval)interval {
    return [context.mirror
        startWithTarget:context.mirrorTarget
        scrollContainer:context.mirrorContainer
                  point:point
             directions:directions
         repeatInterval:interval];
}

- (void)assertStartAcceptanceForContext:
    (IDVADifferentialContext *)context
                                point:(CGPoint)point
                           directions:(NSUInteger)directions
                              interval:(NSTimeInterval)interval
                                   row:(NSString *)row {
    BOOL stockAccepted =
        [self startStock:context
                   point:point
              directions:directions
                 interval:interval];
    BOOL mirrorAccepted =
        [self startMirror:context
                    point:point
               directions:directions
                  interval:interval];
    XCTAssertEqual(
        stockAccepted,
        mirrorAccepted,
        @"row=%@",
        row);
    [self assertStock:context.stock
        matchesMirror:context.mirror
                  row:row];
}

- (void)testUIKitAndMirrorStateMachineRowsMatch {
    NSArray<NSString *> *rows = @[
        @"valid start",
        @"zero direction",
        @"zero interval",
        @"policy rejection",
        @"coalesce at 0",
        @"coalesce at 69.999",
        @"cross-container global distance",
        @"restart at 70",
        @"direction change",
        @"interval change",
        @"two timer fires",
        @"target release",
        @"repeated invalidate",
        @"container release after invalidate",
    ];

    for (NSString *row in rows) {
        @autoreleasepool {
            IDVADifferentialContext *context =
                [IDVADifferentialContext new];
            if ([row isEqualToString:@"valid start"]) {
                [self assertStartAcceptanceForContext:context
                                                point:CGPointMake(12, 88)
                                           directions:8U
                                              interval:10.0
                                                   row:row];
                continue;
            }
            if ([row isEqualToString:@"zero direction"]) {
                [self assertStartAcceptanceForContext:context
                                                point:CGPointZero
                                           directions:0U
                                              interval:0.075
                                                   row:row];
                continue;
            }
            if ([row isEqualToString:@"zero interval"]) {
                [self assertStartAcceptanceForContext:context
                                                point:CGPointZero
                                           directions:8U
                                              interval:0.0
                                                   row:row];
                continue;
            }
            if ([row isEqualToString:@"policy rejection"]) {
                IDVADifferentialPolicyContainer *stockContainer =
                    [IDVADifferentialPolicyContainer new];
                IDVADifferentialPolicyContainer *mirrorContainer =
                    [IDVADifferentialPolicyContainer new];
                stockContainer.permitsAutoscroll = NO;
                mirrorContainer.permitsAutoscroll = NO;
                context.stockContainer = stockContainer;
                context.mirrorContainer = mirrorContainer;
                [self assertStartAcceptanceForContext:context
                                                point:CGPointZero
                                           directions:8U
                                              interval:0.075
                                                   row:row];
                continue;
            }

            XCTAssertTrue([self startStock:context
                                     point:CGPointZero
                                directions:8U
                                   interval:10.0],
                          @"row=%@", row);
            XCTAssertTrue([self startMirror:context
                                      point:CGPointZero
                                 directions:8U
                                    interval:10.0],
                          @"row=%@", row);
            NSDictionary *stockBefore =
                IDPrivateTestingCopyUIKitAutoscrollSnapshot(
                    context.stock);
            IDVADifferentialTimer *mirrorTimer =
                context.timerFactory.timers.firstObject;

            if ([row hasPrefix:@"coalesce at "]) {
                CGFloat x = [row hasSuffix:@"69.999"]
                    ? 69.999
                    : 0.0;
                [self assertStartAcceptanceForContext:context
                                                point:CGPointMake(x, 0)
                                           directions:8U
                                              interval:10.0
                                                   row:row];
                NSDictionary *stockAfter =
                    IDPrivateTestingCopyUIKitAutoscrollSnapshot(
                        context.stock);
                XCTAssertEqualObjects(
                    stockAfter[@"timerIdentity"],
                    stockBefore[@"timerIdentity"],
                    @"row=%@", row);
                XCTAssertEqual(
                    mirrorTimer.rescheduleDates.count,
                    0U,
                    @"row=%@", row);
                continue;
            }
            if ([row isEqualToString:
                    @"cross-container global distance"]) {
                UIView *stockRoot = [[UIView alloc]
                    initWithFrame:CGRectMake(0, 0, 400, 400)];
                UIView *mirrorRoot = [[UIView alloc]
                    initWithFrame:CGRectMake(0, 0, 400, 400)];
                UIScrollView *stockOther = [[UIScrollView alloc]
                    initWithFrame:CGRectMake(100, 0, 200, 100)];
                UIScrollView *mirrorOther = [[UIScrollView alloc]
                    initWithFrame:CGRectMake(100, 0, 200, 100)];
                [stockRoot addSubview:context.stockContainer];
                [stockRoot addSubview:stockOther];
                [mirrorRoot addSubview:context.mirrorContainer];
                [mirrorRoot addSubview:mirrorOther];
                context.stockContainer = stockOther;
                context.mirrorContainer = mirrorOther;
                [self assertStartAcceptanceForContext:context
                                                point:CGPointZero
                                           directions:8U
                                              interval:10.0
                                                   row:row];
                XCTAssertEqual(
                    mirrorTimer.rescheduleDates.count, 1U);
                continue;
            }
            if ([row isEqualToString:@"restart at 70"]) {
                [self assertStartAcceptanceForContext:context
                                                point:CGPointMake(70, 0)
                                           directions:8U
                                              interval:10.0
                                                   row:row];
                XCTAssertEqual(
                    mirrorTimer.rescheduleDates.count, 1U);
                continue;
            }
            if ([row isEqualToString:@"direction change"]) {
                IDPrivateTestingFireUIKitAutoscroll(context.stock);
                [mirrorTimer fire];
                [self assertStartAcceptanceForContext:context
                                                point:CGPointZero
                                           directions:4U
                                              interval:10.0
                                                   row:row];
                XCTAssertEqual(context.mirror.count, 0U);
                continue;
            }
            if ([row isEqualToString:@"interval change"]) {
                IDPrivateTestingFireUIKitAutoscroll(context.stock);
                [mirrorTimer fire];
                [self assertStartAcceptanceForContext:context
                                                point:CGPointZero
                                           directions:8U
                                              interval:11.0
                                                   row:row];
                XCTAssertEqual(context.mirror.count, 1U);
                continue;
            }
            if ([row isEqualToString:@"two timer fires"]) {
                for (NSUInteger index = 0; index < 2; index += 1) {
                    IDPrivateTestingFireUIKitAutoscroll(
                        context.stock);
                    [mirrorTimer fire];
                }
                [self assertStock:context.stock
                    matchesMirror:context.mirror
                              row:row];
                XCTAssertEqualObjects(
                    context.stockTarget.observedCounts,
                    context.mirrorTarget.observedCounts);
                XCTAssertEqualObjects(
                    context.mirrorTarget.observedCounts,
                    (@[@1, @2]));
                continue;
            }
            if ([row isEqualToString:@"target release"]) {
                __weak IDVADifferentialTarget *weakStockTarget =
                    context.stockTarget;
                __weak IDVADifferentialTarget *weakMirrorTarget =
                    context.mirrorTarget;
                context.stockTarget = nil;
                context.mirrorTarget = nil;
                XCTAssertNil(weakStockTarget);
                XCTAssertNil(weakMirrorTarget);
                IDPrivateTestingFireUIKitAutoscroll(context.stock);
                [mirrorTimer fire];
                [self assertStock:context.stock
                    matchesMirror:context.mirror
                              row:row];
                continue;
            }
            if ([row isEqualToString:@"repeated invalidate"]) {
                IDPrivateTestingInvalidateUIKitAutoscroll(
                    context.stock);
                IDPrivateTestingInvalidateUIKitAutoscroll(
                    context.stock);
                [context.mirror invalidate];
                [context.mirror invalidate];
                [self assertStock:context.stock
                    matchesMirror:context.mirror
                              row:row];
                continue;
            }
            if ([row isEqualToString:
                    @"container release after invalidate"]) {
                __weak UIScrollView *weakStockContainer =
                    context.stockContainer;
                __weak UIScrollView *weakMirrorContainer =
                    context.mirrorContainer;
                IDPrivateTestingInvalidateUIKitAutoscroll(
                    context.stock);
                [context.mirror invalidate];
                context.stockContainer = nil;
                context.mirrorContainer = nil;
                XCTAssertNil(weakStockContainer);
                XCTAssertNil(weakMirrorContainer);
                [self assertStock:context.stock
                    matchesMirror:context.mirror
                              row:row];
            }
        }
    }
}

- (NSTimeInterval)medianIntervalForTimestamps:
    (NSArray<NSNumber *> *)timestamps {
    NSMutableArray<NSNumber *> *intervals =
        [NSMutableArray array];
    for (NSUInteger index = 1;
         index < timestamps.count;
         index += 1) {
        [intervals addObject:@(
            timestamps[index].doubleValue -
            timestamps[index - 1].doubleValue)];
    }
    [intervals sortUsingSelector:@selector(compare:)];
    return intervals[intervals.count / 2].doubleValue;
}

- (void)testUIKitAndMirrorRealCadenceMatchWithinDeclaredTolerances {
    static const NSTimeInterval firstFireTolerance = 0.030;
    static const NSTimeInterval medianIntervalTolerance = 0.025;
    id stock = IDPrivateTestingNewUIKitAutoscroll();
    IDVerticalAutoscroll *mirror = [IDVerticalAutoscroll new];
    IDVADifferentialTarget *stockTarget =
        [IDVADifferentialTarget new];
    IDVADifferentialTarget *mirrorTarget =
        [IDVADifferentialTarget new];
    stockTarget.expectation =
        [self expectationWithDescription:@"four stock ticks"];
    stockTarget.expectation.expectedFulfillmentCount = 4;
    mirrorTarget.expectation =
        [self expectationWithDescription:@"four mirror ticks"];
    mirrorTarget.expectation.expectedFulfillmentCount = 4;
    UIScrollView *stockContainer = [UIScrollView new];
    UIScrollView *mirrorContainer = [UIScrollView new];
    CFTimeInterval stockStart = CACurrentMediaTime();
    XCTAssertTrue(IDPrivateTestingStartUIKitAutoscroll(
        stock,
        stockTarget,
        stockContainer,
        CGPointZero,
        8U,
        0.075));
    CFTimeInterval mirrorStart = CACurrentMediaTime();
    XCTAssertTrue([mirror
        startWithTarget:mirrorTarget
        scrollContainer:mirrorContainer
                  point:CGPointZero
             directions:IDVerticalAutoscrollDirectionDown
         repeatInterval:0.075]);

    [self waitForExpectations:@[
        stockTarget.expectation,
        mirrorTarget.expectation,
    ] timeout:0.6];
    IDPrivateTestingInvalidateUIKitAutoscroll(stock);
    [mirror invalidate];

    XCTAssertGreaterThanOrEqual(
        stockTarget.timestamps.count, 4U);
    XCTAssertGreaterThanOrEqual(
        mirrorTarget.timestamps.count, 4U);
    NSTimeInterval stockFirst =
        stockTarget.timestamps.firstObject.doubleValue -
        stockStart;
    NSTimeInterval mirrorFirst =
        mirrorTarget.timestamps.firstObject.doubleValue -
        mirrorStart;
    XCTAssertEqualWithAccuracy(
        mirrorFirst, stockFirst, firstFireTolerance);
    XCTAssertEqualWithAccuracy(
        [self medianIntervalForTimestamps:
            mirrorTarget.timestamps],
        [self medianIntervalForTimestamps:
            stockTarget.timestamps],
        medianIntervalTolerance);
}

@end
