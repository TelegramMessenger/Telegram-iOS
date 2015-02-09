#import "SSignal+Catch.h"

#import "SMetaDisposable.h"
#import "SDisposableSet.h"
#import "SAtomic.h"

@implementation SSignal (Catch)

- (SSignal *)catch:(SSignal *(^)(id error))f
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        
        [disposable setDisposable:[self startWithNext:^(id next)
        {
            [subscriber putNext:next];
        } error:^(id error)
        {
            SSignal *signal = f(error);
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
        } completed:^
        {
            [subscriber putCompletion];
        }]];
        
        return disposable;
    }];
}

@end
