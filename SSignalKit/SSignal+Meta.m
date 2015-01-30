#import "SSignal+Meta.h"

#import "SMetaDisposable.h"
#import "SSignal+Mapping.h"
#import "SAtomic.h"

@implementation SSignal (Meta)

- (SSignal *)switchToLatest
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        SMetaDisposable *currentDisposable = [[SMetaDisposable alloc] init];
        
        SAtomic *didProduceNext = [[SAtomic alloc] initWithValue:nil];
        id<SDisposable> disposable = [self startWithNext:^(SSignal *next)
        {
            [didProduceNext swap:@1];
            id<SDisposable> innerDisposable = [next startWithNext:^(id next)
            {
                SSubscriber_putNext(subscriber, next);
            } error:^(id error)
            {
                SSubscriber_putError(subscriber, error);
            } completed:^
            {
                SSubscriber_putCompletion(subscriber);
            }];
            [currentDisposable setDisposable:innerDisposable];
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            if ([didProduceNext value] == nil)
                SSubscriber_putCompletion(subscriber);
        }];
        
        [subscriber addDisposable:currentDisposable];
        [subscriber addDisposable:disposable];
    }];
}

- (SSignal *)mapToSignal:(SSignal *(^)(id))f
{
    return [[self map:f] switchToLatest];
}

- (SSignal *)then:(SSignal *)signal
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        [subscriber addDisposable:[self startWithNext:^(id next)
        {
            SSubscriber_putNext(subscriber, next);
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
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
        }]];
    }];
}

@end
