#import "SSignal+Mapping.h"

@implementation SSignal (Mapping)

- (SSignal *)map:(id (^)(id))f
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        id<SDisposable> disposable = [self startWithNext:^(id next)
        {
            SSubscriber_putNext(subscriber, f(next));
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            SSubscriber_putCompletion(subscriber);
        }];
        [subscriber addDisposable:disposable];
    }];
}

- (SSignal *)filter:(bool (^)(id))f
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        id<SDisposable> disposable = [self startWithNext:^(id next)
        {
            if (f(next))
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
}

@end
