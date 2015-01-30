#import "SSignal+Timing.h"

#import "SBlockDisposable.h"

#import "STimer.h"

@implementation SSignal (Timing)

- (SSignal *)delay:(NSTimeInterval)seconds onQueue:(SQueue *)queue
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        STimer *timer = [[STimer alloc] initWithTimeout:seconds repeat:false completion:^
        {
            [subscriber addDisposable:[self startWithNext:^(id next)
            {
                SSubscriber_putNext(subscriber, next);
            } error:^(id error)
            {
                SSubscriber_putError(subscriber, error);
            } completed:^
            {
                SSubscriber_putCompletion(subscriber);
            }]];
        } queue:queue];
        
        [subscriber addDisposable:[[SBlockDisposable alloc] initWithBlock:^
        {
            [timer invalidate];
        }]];
        
        [timer start];
    }];
}

@end
