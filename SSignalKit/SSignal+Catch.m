#import "SSignal+Catch.h"

#import "SMetaDisposable.h"

@implementation SSignal (Catch)

- (SSignal *)catch:(SSignal *(^)(id error))f
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        
        [subscriber addDisposable:disposable];
        
        [subscriber addDisposable:[self startWithNext:^(id next)
        {
            SSubscriber_putNext(subscriber, next);
        } error:^(id error)
        {
            SSignal *signal = f(error);
            [subscriber addDisposable:[signal startWithNext:^(id next)
            {
                SSubscriber_putNext(subscriber, next);
            } error:^(id error)
            {
                SSubscriber_putError(subscriber, error);
            } completed:^
            {
                SSubscriber_putCompletion(subscriber);
            }]];
        } completed:^
        {
            SSubscriber_putCompletion(subscriber);
        }]];
    }];
}

@end
