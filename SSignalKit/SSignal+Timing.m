#import "SSignal+Timing.h"

#import "SMetaDisposable.h"
#import "SDisposableSet.h"
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

- (SSignal *)timeout:(NSTimeInterval)seconds onQueue:(SQueue *)queue or:(SSignal *)signal
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];

        STimer *timer = [[STimer alloc] initWithTimeout:seconds repeat:false completion:^
        {
            [disposable setDisposable:[signal startWithNext:^(id next)
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
        [timer start];
        
        [disposable setDisposable:[self startWithNext:^(id next)
        {
            [timer invalidate];
            [subscriber putNext:next];
        } error:^(id error)
        {
            [timer invalidate];
            [subscriber putError:error];
        } completed:^
        {
            [timer invalidate];
            [subscriber putCompletion];
        }]];
        
        return disposable;
    }];
}

@end
