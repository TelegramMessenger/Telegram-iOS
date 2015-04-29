#import "SSignal+Take.h"

#import "SAtomic.h"

@implementation SSignal (Take)

- (SSignal *)take:(NSUInteger)count
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        SAtomic *counter = [[SAtomic alloc] initWithValue:@(0)];
        return [self startWithNext:^(id next)
        {
            __block bool passthrough = false;
            __block bool complete = false;
            [counter modify:^id(NSNumber *currentCount)
            {
                NSUInteger updatedCount = [currentCount unsignedIntegerValue] + 1;
                if (updatedCount <= count)
                    passthrough = true;
                if (updatedCount == count)
                    complete = true;
                return @(updatedCount);
            }];
            
            if (passthrough)
                [subscriber putNext:next];
            if (complete)
                [subscriber putCompletion];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

@end
