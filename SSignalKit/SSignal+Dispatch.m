#import "SSignal+Dispatch.h"
#import "SAtomic.h"
#import "SBlockDisposable.h"
#import "SMetaDisposable.h"

@implementation SSignal (Dispatch)

- (SSignal *)deliverOn:(SQueue *)queue
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            [queue dispatch:^
            {
                [subscriber putNext:next];
            }];
        } error:^(id error)
        {
            [queue dispatch:^
            {
                [subscriber putError:error];
            }];
        } completed:^
        {
            [queue dispatch:^
            {
                [subscriber putCompletion];
            }];
        }];
    }];
}

- (SSignal *)deliverOnThreadPool:(SThreadPool *)threadPool
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SThreadPoolQueue *queue = [threadPool nextQueue];
        return [self startWithNext:^(id next)
        {
            SThreadPoolTask *task = [[SThreadPoolTask alloc] initWithBlock:^(bool (^cancelled)())
            {
                if (!cancelled())
                    [subscriber putNext:next];
            }];
            [queue addTask:task];
        } error:^(id error)
        {
            SThreadPoolTask *task = [[SThreadPoolTask alloc] initWithBlock:^(bool (^cancelled)())
            {
                if (!cancelled())
                    [subscriber putError:error];
            }];
            [queue addTask:task];
        } completed:^
        {
            SThreadPoolTask *task = [[SThreadPoolTask alloc] initWithBlock:^(bool (^cancelled)())
            {
                if (!cancelled())
                    [subscriber putCompletion];
            }];
            [queue addTask:task];
        }];
    }];
}

- (SSignal *)startOn:(SQueue *)queue
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        __block bool isCancelled = false;
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        [disposable setDisposable:[[SBlockDisposable alloc] initWithBlock:^
        {
            isCancelled = true;
        }]];
        
        [queue dispatch:^
        {
            if (!isCancelled)
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
            }
        }];
        
        return disposable;
    }];
}

- (SSignal *)startOnThreadPool:(SThreadPool *)threadPool
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        
        SThreadPoolTask *task = [[SThreadPoolTask alloc] initWithBlock:^(bool (^cancelled)())
        {
            if (cancelled && cancelled())
                return;
            
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
        }];
        
        [disposable setDisposable:[[SBlockDisposable alloc] initWithBlock:^
        {
            [task cancel];
        }]];
        
        [threadPool addTask:task];
        
        return disposable;
    }];
}

@end
