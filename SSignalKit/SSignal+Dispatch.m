#import "SSignal+Dispatch.h"
#import "SAtomic.h"
#import "SBlockDisposable.h"

@implementation SSignal (Dispatch)

- (SSignal *)deliverOn:(SQueue *)queue
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        [subscriber addDisposable:[self startWithNext:^(id next)
        {
            [queue dispatch:^
            {
                SSubscriber_putNext(subscriber, next);
            }];
        } error:^(id error)
        {
            [queue dispatch:^
            {
                SSubscriber_putError(subscriber, error);
            }];
        } completed:^
        {
            [queue dispatch:^
            {
                SSubscriber_putCompletion(subscriber);
            }];
        }]];
    }];
}

- (SSignal *)deliverOnThreadPool:(SThreadPool *)threadPool
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        SAtomic *atomicLastTask = [[SAtomic alloc] initWithValue:nil];
        [subscriber addDisposable:[self startWithNext:^(id next)
        {
            SThreadPoolTask *task = [threadPool prepareTask:^(bool (^cancelled)())
            {
                if (!cancelled())
                    SSubscriber_putNext(subscriber, next);
            }];
            SThreadPoolTask *lastTask = [atomicLastTask swap:task];
            if (lastTask != nil)
                [task addDependency:lastTask];
            [threadPool startTask:task];
        } error:^(id error)
        {
            SThreadPoolTask *task = [threadPool prepareTask:^(bool (^cancelled)())
            {
                if (!cancelled())
                    SSubscriber_putError(subscriber, error);
            }];
            SThreadPoolTask *lastTask = [atomicLastTask swap:task];
            if (lastTask != nil)
                [task addDependency:lastTask];
            [threadPool startTask:task];
        } completed:^
        {
            SThreadPoolTask *task = [threadPool prepareTask:^(bool (^cancelled)())
            {
                if (!cancelled())
                    SSubscriber_putCompletion(subscriber);
            }];
            SThreadPoolTask *lastTask = [atomicLastTask swap:task];
            if (lastTask != nil)
                [task addDependency:lastTask];
            [threadPool startTask:task];
        }]];
    }];
}

- (SSignal *)startOn:(SQueue *)queue
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        [queue dispatch:^
        {
            id<SDisposable> disposable = [self startWithNext:^(id next)
            {
                SSubscriber_putNext(subscriber, next);
            } error:^(id error)
            {
                SSubscriber_putError(subscriber, error);
            } completed:^
            {
                SSubscriber_putCompletion(subscriber);
            }];
            
            [subscriber addDisposable:disposable];
        }];
    }];
}

- (SSignal *)startOnThreadPool:(SThreadPool *)threadPool
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        id taskId = [threadPool addTask:^(bool (^cancelled)())
        {
            if (cancelled && cancelled())
                return;
            
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
        }];
        
        __weak SThreadPool *weakThreadPool = threadPool;
        [subscriber addDisposable:[[SBlockDisposable alloc] initWithBlock:^
        {
            __strong SThreadPool *strongThreadPool = weakThreadPool;
            [strongThreadPool cancelTask:taskId];
        }]];
    }];
}

@end
