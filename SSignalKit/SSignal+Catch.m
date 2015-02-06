#import "SSignal+Catch.h"

#import "SMetaDisposable.h"
#import "SDisposableSet.h"

@implementation SSignal (Catch)

- (SSignal *)catch:(SSignal *(^)(id error))f
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        
        [disposable setDisposable:[self startWithNext:^(id next)
        {
            SSubscriber_putNext(subscriber, next);
        } error:^(id error)
        {
            SSignal *signal = f(error);
            [disposable setDisposable:[signal startWithNext:^(id next)
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
        
        return disposable;
    }];
}

@end
