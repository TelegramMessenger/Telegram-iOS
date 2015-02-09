#import "SSignal+Timing.h"

#import "SMetaDisposable.h"
#import "SBlockDisposable.h"

#import "STimer.h"

@implementation SSignal (Timing)

- (SSignal *)delay:(NSTimeInterval)seconds onQueue:(SQueue *)queue
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        
        STimer *timer = [[STimer alloc] initWithTimeout:seconds repeat:false completion:^
        {
            [disposable setDisposable:[self startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        } queue:queue];
        
        [disposable setDisposable:[[SBlockDisposable alloc] initWithBlock:^
        {
            [timer invalidate];
        }]];
        
        [timer start];
        
        return disposable;
    }];
}

@end
