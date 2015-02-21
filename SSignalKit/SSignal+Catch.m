#import "SSignal+Catch.h"

#import "SMetaDisposable.h"
#import "SDisposableSet.h"
#import "SAtomic.h"

@implementation SSignal (Catch)

- (SSignal *)catch:(SSignal *(^)(id error))f
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SDisposableSet *disposable = [[SDisposableSet alloc] init];
        
        [disposable add:[self startWithNext:^(id next)
        {
            [subscriber putNext:next];
        } error:^(id error)
        {
            SSignal *signal = f(error);
            [disposable add:[signal startWithNext:^(id next)
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
