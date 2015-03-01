#import "SSignal.h"

#import "SBlockDisposable.h"

@interface SSignal ()
{
}

@end

@implementation SSignal

- (instancetype)initWithGenerator:(id<SDisposable> (^)(SSubscriber *))generator
{
    self = [super init];
    if (self != nil)
    {
        _generator = [generator copy];
    }
    return self;
}

- (id<SDisposable>)startWithNext:(void (^)(id next))next error:(void (^)(id error))error completed:(void (^)())completed
{
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:error completed:completed];
    id<SDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[SBlockDisposable alloc] initWithBlock:^
    {
        [subscriber _markTerminatedWithoutDisposal];
        [disposable dispose];
    }];
}

- (id<SDisposable>)startWithNext:(void (^)(id next))next
{
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:nil completed:nil];
    id<SDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return subscriber;
}

- (id<SDisposable>)startWithNext:(void (^)(id next))next completed:(void (^)())completed
{
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:nil completed:completed];
    id<SDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return subscriber;
}

@end
