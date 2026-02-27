#import "SSignal+Catch.h"

#import "SMetaDisposable.h"
#import "SDisposableSet.h"
#import "SBlockDisposable.h"
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

static dispatch_block_t recursiveBlock(void (^block)(dispatch_block_t recurse))
{
    return ^
    {
        block(recursiveBlock(block));
    };
}

- (SSignal *)restart
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SAtomic *shouldRestart = [[SAtomic alloc] initWithValue:@true];
        
        SMetaDisposable *currentDisposable = [[SMetaDisposable alloc] init];
        
        void (^start)() = recursiveBlock(^(dispatch_block_t recurse)
        {
            NSNumber *currentShouldRestart = [shouldRestart with:^id(NSNumber *current)
            {
                return current;
            }];
            
            if ([currentShouldRestart boolValue])
            {
                id<SDisposable> disposable = [self startWithNext:^(id next)
                {
                    [subscriber putNext:next];
                } error:^(id error)
                {
                    [subscriber putError:error];
                } completed:^
                {
                    recurse();
                }];
                [currentDisposable setDisposable:disposable];
            }
        });
        
        start();
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [currentDisposable dispose];
            
            [shouldRestart modify:^id(__unused id current)
            {
                return @false;
            }];
        }];
    }];
}

- (SSignal *)retryIf:(bool (^)(id error))predicate {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SAtomic *shouldRestart = [[SAtomic alloc] initWithValue:@true];
        
        SMetaDisposable *currentDisposable = [[SMetaDisposable alloc] init];
        
        void (^start)() = recursiveBlock(^(dispatch_block_t recurse)
        {
            NSNumber *currentShouldRestart = [shouldRestart with:^id(NSNumber *current)
            {
                return current;
            }];
            
            if ([currentShouldRestart boolValue])
            {
                id<SDisposable> disposable = [self startWithNext:^(id next)
                {
                    [subscriber putNext:next];
                } error:^(id error)
                {
                    if (predicate(error)) {
                        recurse();
                    } else {
                        [subscriber putError:error];
                    }
                } completed:^
                {
                    [shouldRestart modify:^id(__unused id current) {
                         return @false;
                    }];
                    [subscriber putCompletion];
                }];
                [currentDisposable setDisposable:disposable];
            } else {
                [subscriber putCompletion];
            }
        });
        
        start();
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [currentDisposable dispose];
            
            [shouldRestart modify:^id(__unused id current)
            {
                return @false;
            }];
        }];
    }];
}

@end
