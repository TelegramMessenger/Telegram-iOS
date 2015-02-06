#import "SSignal+Meta.h"

#import "SDisposableSet.h"
#import "SMetaDisposable.h"
#import "SSignal+Mapping.h"
#import "SAtomic.h"

@implementation SSignal (Meta)

- (SSignal *)switchToLatest
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SDisposableSet *compositeDisposable = [[SDisposableSet alloc] init];
        
        SMetaDisposable *currentDisposable = [[SMetaDisposable alloc] init];
        [compositeDisposable add:currentDisposable];
        
        SAtomic *didProduceNext = [[SAtomic alloc] initWithValue:nil];
        [compositeDisposable add:[self startWithNext:^(SSignal *next)
        {
            [didProduceNext swap:@1];
            [currentDisposable setDisposable:[next startWithNext:^(id next)
            {
                SSubscriber_putNext(subscriber, next);
            } error:^(id error)
            {
                SSubscriber_putError(subscriber, error);
            } completed:^
            {
                SSubscriber_putCompletion(subscriber);
            }]];
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            if ([didProduceNext swap:@1] == NULL)
                SSubscriber_putCompletion(subscriber);
        }]];
        
        return compositeDisposable;
    }];
}

- (SSignal *)mapToSignal:(SSignal *(^)(id))f
{
    return [[self map:f] switchToLatest];
}

- (SSignal *)then:(SSignal *)signal
{
    SDisposableSet *compositeDisposable = [[SDisposableSet alloc] init];
    
    SMetaDisposable *currentDisposable = [[SMetaDisposable alloc] init];
    [compositeDisposable add:currentDisposable];
    
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        [currentDisposable setDisposable:[self startWithNext:^(id next)
        {
            SSubscriber_putNext(subscriber, next);
        } error:^(id error)
        {
            SSubscriber_putError(subscriber, error);
        } completed:^
        {
            [compositeDisposable add:[signal startWithNext:^(id next)
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
        
        return compositeDisposable;
    }];
}

@end
