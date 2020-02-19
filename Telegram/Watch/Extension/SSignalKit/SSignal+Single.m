#import "SSignal+Single.h"

@implementation SSignal (Single)

+ (SSignal *)single:(id)next
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        [subscriber putNext:next];
        [subscriber putCompletion];
        return nil;
    }];
}

+ (SSignal *)fail:(id)error
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        [subscriber putError:error];
        return nil;
    }];
}

+ (SSignal *)never
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (__unused SSubscriber *subscriber)
    {
        return nil;
    }];
}

+ (SSignal *)complete
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        [subscriber putCompletion];
        return nil;
    }];
}

@end
