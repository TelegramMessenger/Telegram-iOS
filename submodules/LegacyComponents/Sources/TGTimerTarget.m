#import "TGTimerTarget.h"

@implementation TGTimerTarget

+ (NSTimer *)scheduledMainThreadTimerWithTarget:(id)target action:(SEL)action interval:(NSTimeInterval)interval repeat:(bool)repeat
{
    return [self scheduledMainThreadTimerWithTarget:target action:action interval:interval repeat:repeat runLoopModes:NSRunLoopCommonModes];
}

+ (NSTimer *)scheduledMainThreadTimerWithTarget:(id)target action:(SEL)action interval:(NSTimeInterval)interval repeat:(bool)repeat runLoopModes:(NSString *)runLoopModes
{
    TGTimerTarget *timerTarget = [[TGTimerTarget alloc] init];
    timerTarget.target = target;
    timerTarget.action = action;
    
    NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:interval] interval:interval target:timerTarget selector:@selector(timerEvent) userInfo:nil repeats:repeat];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:runLoopModes];
    return timer;
}

- (void)timerEvent
{
    id target = _target;
    if ([target respondsToSelector:_action])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [target performSelector:_action];
#pragma clang diagnostic pop
    }
}

@end
