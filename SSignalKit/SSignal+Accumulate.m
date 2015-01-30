#import "SSignal+Accumulate.h"

@implementation SSignal (Accumulate)

- (SSignal *)reduceLeft:(id)value with:(id (^)(id, id))f
{
    __block id intermediateResult = value;
    
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        id<SDisposable> disposable = [self startWithNext:^(id next)
        {
            intermediateResult = f(intermediateResult, next);
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            if (intermediateResult != nil)
                SSubscriber_putNext(subscriber, intermediateResult);
            SSubscriber_putCompletion(subscriber);
        }];
        
        [subscriber addDisposable:disposable];
    }];
}

@end
