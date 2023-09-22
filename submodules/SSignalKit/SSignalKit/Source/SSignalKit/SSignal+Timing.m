#import "SSignal+Timing.h"

#import "SMetaDisposable.h"
#import "SDisposableSet.h"
#import "SBlockDisposable.h"

#import "SSignal+Dispatch.h"

#import "STimer.h"

@implementation SSignal (Timing)

- (SSignal *)delay:(NSTimeInterval)seconds onQueue:(SQueue *)queue
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SMetaDisposable *startDisposable = [[SMetaDisposable alloc] init];
        SMetaDisposable *timerDisposable = [[SMetaDisposable alloc] init];
        
        STimer *timer = [[STimer alloc] initWithTimeout:seconds repeat:false completion:^(__unused STimer *timer) {
            [startDisposable setDisposable:[self startWithNext:^(id next)
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
        
        [timerDisposable setDisposable:[[SBlockDisposable alloc] initWithBlock:^
        {
            [timer invalidate];
        }]];
        
        return [[SBlockDisposable alloc] initWithBlock:^{
            [startDisposable dispose];
            [timerDisposable dispose];
        }];
    }];
}

- (SSignal *)timeout:(NSTimeInterval)seconds onQueue:(SQueue *)queue orSignal:(SSignal *)signal
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SMetaDisposable *startDisposable = [[SMetaDisposable alloc] init];
        SMetaDisposable *timerDisposable = [[SMetaDisposable alloc] init];

        STimer *timer = [[STimer alloc] initWithTimeout:seconds repeat:false completion:^(__unused STimer *timer)
        {
            [startDisposable setDisposable:[signal startWithNext:^(id next)
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
        
        [timerDisposable setDisposable:[self startWithNext:^(id next)
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
        
        return [[SBlockDisposable alloc] initWithBlock:^{
            [startDisposable dispose];
            [timerDisposable dispose];
        }];
    }];
}

- (SSignal *)wait:(NSTimeInterval)seconds
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        id<SDisposable> disposable = [self startWithNext:^(id next)
        {
            dispatch_semaphore_signal(semaphore);
            [subscriber putNext:next];
        } error:^(id error)
        {
            dispatch_semaphore_signal(semaphore);
            [subscriber putError:error];
        } completed:^
        {
            dispatch_semaphore_signal(semaphore);
            [subscriber putCompletion];
        }];
        
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)));
        
        return disposable;
    }];
}

@end
