#import <XCTest/XCTest.h>

#import "IDVerticalAutoscrollInternal.h"

@interface IDVerticalAutoscrollFakeTimer :
    NSObject <IDVerticalAutoscrollTimer>
@property(nonatomic, copy) dispatch_block_t callback;
@property(nonatomic, strong) NSMutableArray<NSDate *> *fireDates;
@property(nonatomic) BOOL invalidated;
@property(nonatomic) BOOL invalidatedOnMainThread;
@property(nonatomic, strong, nullable)
    XCTestExpectation *invalidationExpectation;
- (void)fire;
@end

@implementation IDVerticalAutoscrollFakeTimer

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _fireDates = [NSMutableArray array];
    }
    return self;
}

- (void)setFireDate:(NSDate *)date {
    [self.fireDates addObject:date];
}

- (void)invalidate {
    self.invalidated = YES;
    self.invalidatedOnMainThread = NSThread.isMainThread;
    [self.invalidationExpectation fulfill];
}

- (void)fire {
    if (!self.invalidated && self.callback != nil) {
        self.callback();
    }
}

@end

@interface IDVerticalAutoscrollTimerProbe : NSObject
@property(nonatomic, strong)
    NSMutableArray<IDVerticalAutoscrollFakeTimer *> *timers;
@property(nonatomic, strong) NSMutableArray<NSDate *> *creationDates;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *intervals;
- (IDVerticalAutoscrollTimerFactory)factory;
@end

@implementation IDVerticalAutoscrollTimerProbe

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _timers = [NSMutableArray array];
        _creationDates = [NSMutableArray array];
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
        IDVerticalAutoscrollFakeTimer *timer =
            [IDVerticalAutoscrollFakeTimer new];
        timer.callback = callback;
        [weakSelf.timers addObject:timer];
        [weakSelf.creationDates addObject:fireDate];
        [weakSelf.intervals addObject:@(interval)];
        return timer;
    };
}

@end

@interface IDVerticalAutoscrollTargetProbe :
    NSObject <IDVerticalAutoscrollTarget>
@property(nonatomic) NSUInteger callbackCount;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *observedCounts;
@end

@implementation IDVerticalAutoscrollTargetProbe

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _observedCounts = [NSMutableArray array];
    }
    return self;
}

- (void)updateVerticalAutoscroll:
    (IDVerticalAutoscroll *)autoscroll {
    self.callbackCount += 1;
    [self.observedCounts addObject:@(autoscroll.count)];
}

@end

@interface IDVerticalAutoscrollPolicyScrollView : UIScrollView
    <IDVerticalAutoscrollContainerPolicy>
@property(nonatomic) BOOL permitsAutoscroll;
@end

@implementation IDVerticalAutoscrollPolicyScrollView
- (BOOL)id_shouldAutoscroll {
    return self.permitsAutoscroll;
}
@end

@interface IDVerticalAutoscrollTests : XCTestCase
@property(nonatomic, strong) IDVerticalAutoscrollTimerProbe *timerProbe;
@property(nonatomic, strong) IDVerticalAutoscroll *autoscroll;
@property(nonatomic, strong) IDVerticalAutoscrollTargetProbe *target;
@property(nonatomic, strong) UIScrollView *container;
@end

@implementation IDVerticalAutoscrollTests

- (void)setUp {
    [super setUp];
    self.timerProbe = [IDVerticalAutoscrollTimerProbe new];
    self.autoscroll = [[IDVerticalAutoscroll alloc]
        initWithTimerFactory:self.timerProbe.factory];
    self.target = [IDVerticalAutoscrollTargetProbe new];
    self.container = [[UIScrollView alloc]
        initWithFrame:CGRectMake(0, 0, 200, 100)];
}

- (BOOL)startAtPoint:(CGPoint)point
          directions:(IDVerticalAutoscrollDirection)directions
             interval:(NSTimeInterval)interval {
    return [self.autoscroll
        startWithTarget:self.target
        scrollContainer:self.container
                  point:point
             directions:directions
         repeatInterval:interval];
}

- (void)testAcceptedStartSchedulesImmediatelyWithExactInterval {
    NSDate *before = [NSDate date];
    XCTAssertTrue([self startAtPoint:CGPointMake(12, 88)
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.075]);
    NSDate *after = [NSDate date];

    XCTAssertTrue(self.autoscroll.isActive);
    XCTAssertIdentical(self.autoscroll.target, self.target);
    XCTAssertIdentical(self.autoscroll.id_scrollContainer, self.container);
    XCTAssertTrue(CGPointEqualToPoint(
        self.autoscroll.point, CGPointMake(12, 88)));
    XCTAssertEqual(
        self.autoscroll.directions,
        IDVerticalAutoscrollDirectionDown);
    XCTAssertEqual(self.autoscroll.repeatInterval, 0.075);
    XCTAssertEqual(self.autoscroll.count, 0U);
    XCTAssertEqual(self.timerProbe.timers.count, 1U);
    XCTAssertEqualObjects(self.timerProbe.intervals, (@[@0.075]));
    NSDate *fireDate = self.timerProbe.creationDates.firstObject;
    XCTAssertEqual([fireDate compare:before], NSOrderedDescending);
    XCTAssertNotEqual([fireDate compare:after], NSOrderedDescending);
}

- (void)testOwnsTargetWeaklyAndContainerStronglyOnlyWhileActive {
    __weak IDVerticalAutoscrollTargetProbe *weakTarget;
    __weak UIScrollView *weakContainer;
    @autoreleasepool {
        IDVerticalAutoscrollTargetProbe *target =
            [IDVerticalAutoscrollTargetProbe new];
        UIScrollView *container = [UIScrollView new];
        weakTarget = target;
        weakContainer = container;
        XCTAssertTrue([self.autoscroll
            startWithTarget:target
            scrollContainer:container
                      point:CGPointZero
                 directions:IDVerticalAutoscrollDirectionDown
             repeatInterval:0.075]);
    }

    XCTAssertNil(weakTarget);
    XCTAssertNotNil(weakContainer);
    [self.autoscroll invalidate];
    XCTAssertNil(weakContainer);
}

- (void)testEveryInvalidStartInvalidatesTheCurrentSession {
    NSArray<void (^)(void)> *invalidStarts = @[
        ^{
            id incompatible = [NSObject new];
            XCTAssertFalse([self.autoscroll
                startWithTarget:incompatible
                scrollContainer:self.container
                          point:CGPointZero
                     directions:IDVerticalAutoscrollDirectionDown
                 repeatInterval:0.075]);
        },
        ^{
            XCTAssertFalse([self.autoscroll
                startWithTarget:self.target
                scrollContainer:nil
                          point:CGPointZero
                     directions:IDVerticalAutoscrollDirectionDown
                 repeatInterval:0.075]);
        },
        ^{
            XCTAssertFalse([self startAtPoint:CGPointZero
                                   directions:0
                                      interval:0.075]);
        },
        ^{
            XCTAssertFalse([self startAtPoint:CGPointZero
                                   directions:IDVerticalAutoscrollDirectionDown
                                      interval:0.0]);
        },
        ^{
            self.autoscroll.disabled = YES;
            XCTAssertFalse([self startAtPoint:CGPointZero
                                   directions:IDVerticalAutoscrollDirectionDown
                                      interval:0.075]);
            self.autoscroll.disabled = NO;
        },
        ^{
            IDVerticalAutoscrollPolicyScrollView *container =
                [IDVerticalAutoscrollPolicyScrollView new];
            container.permitsAutoscroll = NO;
            XCTAssertFalse([self.autoscroll
                startWithTarget:self.target
                scrollContainer:container
                          point:CGPointZero
                     directions:IDVerticalAutoscrollDirectionDown
                 repeatInterval:0.075]);
        },
    ];

    for (void (^invalidStart)(void) in invalidStarts) {
        XCTAssertTrue([self startAtPoint:CGPointZero
                             directions:IDVerticalAutoscrollDirectionDown
                                interval:0.075]);
        IDVerticalAutoscrollFakeTimer *timer =
            self.timerProbe.timers.lastObject;
        invalidStart();
        XCTAssertTrue(timer.invalidated);
        XCTAssertFalse(self.autoscroll.isActive);
        XCTAssertNil(self.autoscroll.target);
        XCTAssertNil(self.autoscroll.id_scrollContainer);
    }
}

- (void)testPointOnlyCoalescingUsesStrictGlobalSeventyPointThreshold {
    XCTAssertTrue([self startAtPoint:CGPointZero
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.075]);
    IDVerticalAutoscrollFakeTimer *timer =
        self.timerProbe.timers.firstObject;
    [timer fire];

    XCTAssertTrue([self startAtPoint:CGPointMake(69.999, 0)
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.075]);

    XCTAssertEqual(self.timerProbe.timers.count, 1U);
    XCTAssertEqual(timer.fireDates.count, 0U);
    XCTAssertFalse(timer.invalidated);
    XCTAssertEqual(self.autoscroll.count, 1U);
    XCTAssertTrue(CGPointEqualToPoint(
        self.autoscroll.point, CGPointMake(69.999, 0)));
}

- (void)testCoalescingMeasuresGlobalCoordinatesInsteadOfRawLocalDistance {
    UIWindow *window = [UIWindow new];
    window.frame = CGRectMake(0, 0, 400, 400);
    self.container.transform = CGAffineTransformMakeScale(2.0, 2.0);
    [window addSubview:self.container];
    XCTAssertTrue([self startAtPoint:CGPointZero
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.075]);
    IDVerticalAutoscrollFakeTimer *timer =
        self.timerProbe.timers.firstObject;

    XCTAssertTrue([self startAtPoint:CGPointMake(40, 0)
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.075]);

    XCTAssertEqual(self.timerProbe.timers.count, 1U);
    XCTAssertEqual(timer.fireDates.count, 1U);
}

- (void)testTrueRestartsRescheduleExistingTimerAndResetCountOnlyForDirection {
    XCTAssertTrue([self startAtPoint:CGPointZero
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.075]);
    IDVerticalAutoscrollFakeTimer *timer =
        self.timerProbe.timers.firstObject;
    [timer fire];
    XCTAssertEqual(self.autoscroll.count, 1U);

    XCTAssertTrue([self startAtPoint:CGPointMake(70, 0)
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.075]);
    XCTAssertEqual(self.timerProbe.timers.count, 1U);
    XCTAssertEqual(timer.fireDates.count, 1U);
    XCTAssertEqual(self.autoscroll.count, 1U);

    XCTAssertTrue([self startAtPoint:CGPointMake(70, 0)
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.1]);
    XCTAssertEqual(self.timerProbe.timers.count, 1U);
    XCTAssertEqual(timer.fireDates.count, 2U);
    XCTAssertEqual(self.autoscroll.repeatInterval, 0.1);
    XCTAssertEqual(self.autoscroll.count, 1U);

    XCTAssertTrue([self startAtPoint:CGPointMake(70, 0)
                         directions:IDVerticalAutoscrollDirectionUp
                            interval:0.1]);
    XCTAssertEqual(timer.fireDates.count, 3U);
    XCTAssertEqual(self.autoscroll.count, 0U);
}

- (void)testTargetOrContainerChangeForcesRestart {
    XCTAssertTrue([self startAtPoint:CGPointZero
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.075]);
    IDVerticalAutoscrollFakeTimer *timer =
        self.timerProbe.timers.firstObject;
    [timer fire];

    IDVerticalAutoscrollTargetProbe *otherTarget =
        [IDVerticalAutoscrollTargetProbe new];
    XCTAssertTrue([self.autoscroll
        startWithTarget:otherTarget
        scrollContainer:self.container
                  point:CGPointZero
             directions:IDVerticalAutoscrollDirectionDown
         repeatInterval:0.075]);
    XCTAssertEqual(timer.fireDates.count, 1U);
    XCTAssertEqual(self.autoscroll.count, 1U);

    UIWindow *window = [UIWindow new];
    window.frame = CGRectMake(0, 0, 400, 400);
    UIScrollView *otherContainer =
        [[UIScrollView alloc] initWithFrame:CGRectMake(100, 0, 200, 100)];
    [window addSubview:self.container];
    [window addSubview:otherContainer];
    XCTAssertTrue([self.autoscroll
        startWithTarget:otherTarget
        scrollContainer:otherContainer
                  point:CGPointZero
             directions:IDVerticalAutoscrollDirectionDown
         repeatInterval:0.075]);
    XCTAssertEqual(timer.fireDates.count, 2U);
    XCTAssertIdentical(self.autoscroll.id_scrollContainer, otherContainer);
}

- (void)testFireIncrementsCountBeforeCallback {
    XCTAssertTrue([self startAtPoint:CGPointZero
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.075]);
    IDVerticalAutoscrollFakeTimer *timer =
        self.timerProbe.timers.firstObject;

    [timer fire];
    [timer fire];

    XCTAssertEqualObjects(self.target.observedCounts, (@[@1, @2]));
    XCTAssertEqual(self.autoscroll.count, 2U);
}

- (void)testTargetDisappearanceDuringFireInvalidatesSession {
    __weak IDVerticalAutoscrollTargetProbe *weakTarget = self.target;
    XCTAssertTrue([self startAtPoint:CGPointZero
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.075]);
    IDVerticalAutoscrollFakeTimer *timer =
        self.timerProbe.timers.firstObject;
    self.target = nil;
    XCTAssertNil(weakTarget);

    [timer fire];

    XCTAssertTrue(timer.invalidated);
    XCTAssertFalse(self.autoscroll.isActive);
    XCTAssertEqual(self.autoscroll.count, 0U);
}

- (void)testInvalidateIsIdempotentAndClearsEverySessionField {
    XCTAssertTrue([self startAtPoint:CGPointMake(4, 5)
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.075]);
    IDVerticalAutoscrollFakeTimer *timer =
        self.timerProbe.timers.firstObject;
    [timer fire];

    [self.autoscroll invalidate];
    [self.autoscroll invalidate];

    XCTAssertTrue(timer.invalidated);
    XCTAssertFalse(self.autoscroll.isActive);
    XCTAssertNil(self.autoscroll.target);
    XCTAssertNil(self.autoscroll.id_scrollContainer);
    XCTAssertTrue(CGPointEqualToPoint(
        self.autoscroll.point, CGPointZero));
    XCTAssertEqual(self.autoscroll.directions, 0U);
    XCTAssertEqual(self.autoscroll.repeatInterval, 0.0);
    XCTAssertEqual(self.autoscroll.count, 0U);
}

- (void)testDeallocationInvalidatesTimer {
    IDVerticalAutoscrollFakeTimer *timer;
    @autoreleasepool {
        IDVerticalAutoscroll *autoscroll =
            [[IDVerticalAutoscroll alloc]
                initWithTimerFactory:self.timerProbe.factory];
        XCTAssertTrue([autoscroll
            startWithTarget:self.target
            scrollContainer:self.container
                      point:CGPointZero
                 directions:IDVerticalAutoscrollDirectionDown
             repeatInterval:0.075]);
        timer = self.timerProbe.timers.lastObject;
        autoscroll = nil;
    }
    XCTAssertTrue(timer.invalidated);
}

- (void)testOffMainDeallocationInvalidatesTimerOnMainThread {
    __block IDVerticalAutoscroll *autoscroll =
        [[IDVerticalAutoscroll alloc]
            initWithTimerFactory:self.timerProbe.factory];
    XCTAssertTrue([autoscroll
        startWithTarget:self.target
        scrollContainer:self.container
                  point:CGPointZero
             directions:IDVerticalAutoscrollDirectionDown
         repeatInterval:0.075]);
    IDVerticalAutoscrollFakeTimer *timer =
        self.timerProbe.timers.lastObject;
    timer.invalidationExpectation =
        [self expectationWithDescription:
            @"off-main deallocation invalidated timer"];

    dispatch_async(
        dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            autoscroll = nil;
        });

    [self waitForExpectations:@[timer.invalidationExpectation]
                      timeout:1.0];
    XCTAssertTrue(timer.invalidated);
    XCTAssertTrue(timer.invalidatedOnMainThread);
}

- (void)testOffMainInvalidateReturnsBeforeMainThreadCleanup {
    XCTAssertTrue([self startAtPoint:CGPointZero
                         directions:IDVerticalAutoscrollDirectionDown
                            interval:0.075]);
    IDVerticalAutoscrollFakeTimer *timer =
        self.timerProbe.timers.firstObject;
    XCTestExpectation *returned =
        [self expectationWithDescription:@"background call returned"];
    XCTestExpectation *cleaned =
        [self expectationWithDescription:@"main cleanup completed"];

    dispatch_async(
        dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [self.autoscroll invalidate];
            [returned fulfill];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (timer.invalidated) {
                    [cleaned fulfill];
                }
            });
        });

    [self waitForExpectations:@[returned, cleaned] timeout:1.0];
    XCTAssertTrue(timer.invalidated);
    XCTAssertTrue(timer.invalidatedOnMainThread);
    XCTAssertFalse(self.autoscroll.isActive);
}

@end
