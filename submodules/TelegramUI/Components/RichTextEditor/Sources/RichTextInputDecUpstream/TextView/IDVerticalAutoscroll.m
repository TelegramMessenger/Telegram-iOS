#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDVerticalAutoscrollInternal.h"

#include <math.h>

@interface IDVerticalAutoscroll ()
@property(nonatomic, weak, readwrite, nullable)
    id<IDVerticalAutoscrollTarget> target;
@property(nonatomic, strong, readwrite, nullable)
    UIScrollView *scrollContainer;
@property(nonatomic, readwrite) CGPoint point;
@property(nonatomic, readwrite)
    IDVerticalAutoscrollDirection directions;
@property(nonatomic, readwrite) NSTimeInterval repeatInterval;
@property(nonatomic, readwrite) NSUInteger count;
@property(nonatomic, getter=isActive, readwrite) BOOL active;
@property(nonatomic, copy)
    IDVerticalAutoscrollTimerFactory timerFactory;
@property(nonatomic, strong, nullable)
    id<IDVerticalAutoscrollTimer> timer;
@end

@implementation IDVerticalAutoscroll

static IDVerticalAutoscrollTimerFactory
IDVerticalAutoscrollProductionTimerFactory(void) {
    return ^id<IDVerticalAutoscrollTimer>(
        NSDate *fireDate,
        NSTimeInterval interval,
        dispatch_block_t callback) {
        NSTimer *timer = [[NSTimer alloc]
            initWithFireDate:fireDate
                    interval:interval
                     repeats:YES
                       block:^(NSTimer *firedTimer) {
                           (void)firedTimer;
                           callback();
                       }];
        [NSRunLoop.currentRunLoop addTimer:timer
                                  forMode:NSDefaultRunLoopMode];
        return (id<IDVerticalAutoscrollTimer>)timer;
    };
}

- (instancetype)init {
    return [self initWithTimerFactory:
        IDVerticalAutoscrollProductionTimerFactory()];
}

- (instancetype)initWithTimerFactory:
    (IDVerticalAutoscrollTimerFactory)timerFactory {
    NSParameterAssert(timerFactory != nil);
    self = [super init];
    if (self != nil) {
        _timerFactory = [timerFactory copy];
    }
    return self;
}

- (BOOL)startWithTarget:
    (nullable id<IDVerticalAutoscrollTarget>)target
        scrollContainer:(nullable UIScrollView *)scrollContainer
                  point:(CGPoint)point
             directions:
    (IDVerticalAutoscrollDirection)directions
         repeatInterval:(NSTimeInterval)repeatInterval {
    BOOL targetIsValid =
        target != nil &&
        [target conformsToProtocol:
            @protocol(IDVerticalAutoscrollTarget)] &&
        [target respondsToSelector:
            @selector(updateVerticalAutoscroll:)];
    BOOL containerPermitsAutoscroll = YES;
    if ([scrollContainer respondsToSelector:
            @selector(id_shouldAutoscroll)]) {
        containerPermitsAutoscroll =
            [(id<IDVerticalAutoscrollContainerPolicy>)
                scrollContainer id_shouldAutoscroll];
    }
    if (!targetIsValid ||
        self.isDisabled ||
        scrollContainer == nil ||
        !containerPermitsAutoscroll ||
        directions == 0 ||
        repeatInterval == 0.0) {
        [self invalidate];
        return NO;
    }

    if (self.timer != nil &&
        self.target == target &&
        self.scrollContainer == scrollContainer &&
        self.directions == directions &&
        self.repeatInterval == repeatInterval) {
        CGPoint oldGlobal =
            [self.scrollContainer convertPoint:self.point
                                         toView:nil];
        CGPoint newGlobal =
            [scrollContainer convertPoint:point toView:nil];
        CGFloat deltaX = newGlobal.x - oldGlobal.x;
        CGFloat deltaY = newGlobal.y - oldGlobal.y;
        CGFloat distance =
            sqrt(deltaX * deltaX + deltaY * deltaY);
        if (distance < 70.0) {
            self.point = point;
            return YES;
        }
    }

    NSDate *fireDate = [NSDate date];
    if (self.timer != nil) {
        [self.timer setFireDate:fireDate];
    } else {
        __weak typeof(self) weakSelf = self;
        self.timer = self.timerFactory(
            fireDate,
            repeatInterval,
            ^{
                [weakSelf id_timerFired];
            });
    }
    if (self.directions != directions) {
        self.count = 0;
    }
    self.target = target;
    self.scrollContainer = scrollContainer;
    self.point = point;
    self.directions = directions;
    self.repeatInterval = repeatInterval;
    self.active = YES;
    return YES;
}

- (void)id_timerFired {
    self.count += 1;
    id<IDVerticalAutoscrollTarget> target = self.target;
    if (target == nil) {
        [self invalidate];
        return;
    }
    [target updateVerticalAutoscroll:self];
}

- (void)id_invalidateOnMainThread {
    [self.timer invalidate];
    self.timer = nil;
    self.target = nil;
    self.scrollContainer = nil;
    self.point = CGPointZero;
    self.directions = 0;
    self.repeatInterval = 0.0;
    self.count = 0;
    self.active = NO;
}

- (void)invalidate {
    if (NSThread.isMainThread) {
        [self id_invalidateOnMainThread];
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self id_invalidateOnMainThread];
    });
}

- (void)dealloc {
    id<IDVerticalAutoscrollTimer> timer = _timer;
    if (timer == nil) return;
    if (NSThread.isMainThread) {
        [timer invalidate];
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [timer invalidate];
    });
}

@end

#endif
