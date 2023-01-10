#import "SSignal.h"

#import "SBlockDisposable.h"

#import <libkern/OSAtomic.h>

@interface SSubscriberDisposable : NSObject <SDisposable>
{
    OSSpinLock _lock;
    __weak SSubscriber *_subscriber;
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
    id<SDisposable> disposable;
    
    OSSpinLockLock(&_lock);
    disposable = _disposable;
    _disposable = nil;
    OSSpinLockUnlock(&_lock);
    
    [_subscriber _markTerminatedWithoutDisposal];
    [disposable dispose];
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

- (id<SDisposable>)startWithNext:(void (^)(id next))next error:(void (^)(id error))error completed:(void (^)())completed traceName:(NSString *)traceName
{
    STracingSubscriber *subscriber = [[STracingSubscriber alloc] initWithName:traceName next:next error:error completed:completed];
    id<SDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[SSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
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

- (SSignal *)trace:(NSString *)name
{
#ifdef DEBUG
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSString *traceName = [[NSString alloc] initWithFormat:@"%@#0x%x", name, (int)random()];
        NSLog(@"trace(%@ start)", traceName);
        return [self startWithNext:^(id next)
        {
            [subscriber putNext:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        } traceName:traceName];
    }];
#else
    return self;
#endif
}

@end
