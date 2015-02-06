#import "SSignal+SideEffects.h"

#import "SBlockDisposable.h"
#import "SDisposableSet.h"

@implementation SSignal (SideEffects)

- (SSignal *)onNext:(void (^)(id next))f
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            f(next);
            SSubscriber_putNext(subscriber, next);
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            SSubscriber_putCompletion(subscriber);
        }];
    }];
}

- (SSignal *)onError:(void (^)(id error))f
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            SSubscriber_putNext(subscriber, next);
        } error:^(id error)
        {
            f(error);
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            SSubscriber_putCompletion(subscriber);
        }];
    }];
}

- (SSignal *)onCompletion:(void (^)())f
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            SSubscriber_putNext(subscriber, next);
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            f();
            SSubscriber_putCompletion(subscriber);
        }];
    }];
}

- (SSignal *)onDispose:(void (^)())f
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        SDisposableSet *compositeDisposable = [[SDisposableSet alloc] init];
        
        [compositeDisposable add:[self startWithNext:^(id next)
        {
            SSubscriber_putNext(subscriber, next);
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            SSubscriber_putCompletion(subscriber);
        }]];
        
        [compositeDisposable add:[[SBlockDisposable alloc] initWithBlock:^
        {
            f();
        }]];
        
        return compositeDisposable;
    }];
}

@end
