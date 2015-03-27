#import "SSignal.h"

#import "SBlockDisposable.h"

@interface SSubscriberDisposable : NSObject <SDisposable>
{
    SSubscriber *_subscriber;
    id<SDisposable> _disposable;
}

@end

@implementation SSubscriberDisposable

- (instancetype)initWithSubscriber:(SSubscriber *)subscriber disposable:(id<SDisposable>)disposable
{
    self = [super init];
    if (self != nil)
    {
        _subscriber = subscriber;
        _disposable = disposable;
    }
    return self;
}

- (void)dispose
{
    [_subscriber _markTerminatedWithoutDisposal];
    [_disposable dispose];
}

@end

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
    return [[SSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
}

- (id<SDisposable>)startWithNext:(void (^)(id next))next
{
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:nil completed:nil];
    id<SDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[SSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
}

- (id<SDisposable>)startWithNext:(void (^)(id next))next completed:(void (^)())completed
{
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:nil completed:completed];
    id<SDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[SSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
}

@end
