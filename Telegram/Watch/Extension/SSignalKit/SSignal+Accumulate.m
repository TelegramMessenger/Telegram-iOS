#import "SSignal+Accumulate.h"

@implementation SSignal (Accumulate)

- (SSignal *)reduceLeft:(id)value with:(id (^)(id, id))f
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        __block id intermediateResult = value;
        
        return [self startWithNext:^(id next)
        {
            intermediateResult = f(intermediateResult, next);
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            if (intermediateResult != nil)
                [subscriber putNext:intermediateResult];
            [subscriber putCompletion];
        }];
    }];
}

- (SSignal *)reduceLeftWithPassthrough:(id)value with:(id (^)(id, id, void (^)(id)))f
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        __block id intermediateResult = value;
        
        void (^emit)(id) = ^(id next)
        {
            [subscriber putNext:next];
        };
        
        return [self startWithNext:^(id next)
        {
            intermediateResult = f(intermediateResult, next, emit);
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            if (intermediateResult != nil)
                [subscriber putNext:intermediateResult];
            [subscriber putCompletion];
        }];
    }];
}

@end
