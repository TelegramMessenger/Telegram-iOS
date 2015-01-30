#import "SSignal+SideEffects.h"

#import "SBlockDisposable.h"

@implementation SSignal (SideEffects)

- (SSignal *)onNext:(void (^)(id next))f
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        [subscriber addDisposable:[self startWithNext:^(id next)
        {
            f(next);
            SSubscriber_putNext(subscriber, next);
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            SSubscriber_putCompletion(subscriber);
        }]];
    }];
}

- (SSignal *)onError:(void (^)(id error))f
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        [subscriber addDisposable:[self startWithNext:^(id next)
        {
            SSubscriber_putNext(subscriber, next);
        } error:^(id error)
        {
            f(error);
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            SSubscriber_putCompletion(subscriber);
        }]];
    }];
}

- (SSignal *)onCompletion:(void (^)())f
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        [subscriber addDisposable:[self startWithNext:^(id next)
        {
            SSubscriber_putNext(subscriber, next);
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            f();
            SSubscriber_putCompletion(subscriber);
        }]];
    }];
}

- (SSignal *)onDispose:(void (^)())f
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
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
        
        [subscriber addDisposable:[[SBlockDisposable alloc] initWithBlock:^
        {
            f();
        }]];
    }];
}

@end
