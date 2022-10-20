#import "SMulticastSignalManager.h"

#import "SSignal+Multicast.h"
#import "SSignal+SideEffects.h"
#import "SBag.h"
#import "SMetaDisposable.h"
#import "SBlockDisposable.h"

#import <os/lock.h>

@interface SMulticastSignalManager ()
{
    os_unfair_lock _lock;
    NSMutableDictionary *_multicastSignals;
    NSMutableDictionary *_standaloneSignalDisposables;
    NSMutableDictionary *_pipeListeners;
}

@end

@implementation SMulticastSignalManager

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _multicastSignals = [[NSMutableDictionary alloc] init];
        _standaloneSignalDisposables = [[NSMutableDictionary alloc] init];
        _pipeListeners = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    NSArray *disposables = nil;
    os_unfair_lock_lock(&_lock);
    disposables = [_standaloneSignalDisposables allValues];
    os_unfair_lock_unlock(&_lock);
    
    for (id<SDisposable> disposable in disposables)
    {
        [disposable dispose];
    }
}

- (SSignal *)multicastedSignalForKey:(NSString *)key producer:(SSignal *(^)())producer
{
    if (key == nil)
    {
        if (producer)
            return producer();
        else
            return nil;
    }
    
    SSignal *signal = nil;
    os_unfair_lock_lock(&_lock);
    signal = _multicastSignals[key];
    if (signal == nil)
    {
        __weak SMulticastSignalManager *weakSelf = self;
        if (producer)
            signal = producer();
        if (signal != nil)
        {
            signal = [[signal onDispose:^
            {
                __strong SMulticastSignalManager *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    os_unfair_lock_lock(&strongSelf->_lock);
                    [strongSelf->_multicastSignals removeObjectForKey:key];
                    os_unfair_lock_unlock(&strongSelf->_lock);
                }
            }] multicast];
            _multicastSignals[key] = signal;
        }
    }
    os_unfair_lock_unlock(&_lock);
    
    return signal;
}

- (void)startStandaloneSignalIfNotRunningForKey:(NSString *)key producer:(SSignal *(^)())producer
{
    if (key == nil)
        return;
    
    bool produce = false;
    os_unfair_lock_lock(&_lock);
    if (_standaloneSignalDisposables[key] == nil)
    {
        _standaloneSignalDisposables[key] = [[SMetaDisposable alloc] init];
        produce = true;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (produce)
    {
        __weak SMulticastSignalManager *weakSelf = self;
        id<SDisposable> disposable = [producer() startWithNext:nil error:^(__unused id error)
        {
            __strong SMulticastSignalManager *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                os_unfair_lock_lock(&strongSelf->_lock);
                [strongSelf->_standaloneSignalDisposables removeObjectForKey:key];
                os_unfair_lock_unlock(&strongSelf->_lock);
            }
        } completed:^
        {
            __strong SMulticastSignalManager *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                os_unfair_lock_lock(&strongSelf->_lock);
                [strongSelf->_standaloneSignalDisposables removeObjectForKey:key];
                os_unfair_lock_unlock(&strongSelf->_lock);
            }
        }];
        
        os_unfair_lock_lock(&_lock);
        [(SMetaDisposable *)_standaloneSignalDisposables[key] setDisposable:disposable];
        os_unfair_lock_unlock(&_lock);
    }
}

- (SSignal *)multicastedPipeForKey:(NSString *)key
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        os_unfair_lock_lock(&_lock);
        SBag *bag = _pipeListeners[key];
        if (bag == nil)
        {
            bag = [[SBag alloc] init];
            _pipeListeners[key] = bag;
        }
        NSInteger index = [bag addItem:[^(id next)
        {
            [subscriber putNext:next];
        } copy]];
        os_unfair_lock_unlock(&_lock);
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            os_unfair_lock_lock(&_lock);
            SBag *bag = _pipeListeners[key];
            [bag removeItem:index];
            if ([bag isEmpty]) {
                [_pipeListeners removeObjectForKey:key];
            }
            os_unfair_lock_unlock(&_lock);
        }];
    }];
}

- (void)putNext:(id)next toMulticastedPipeForKey:(NSString *)key
{
    os_unfair_lock_lock(&_lock);
    NSArray *pipeListeners = [(SBag *)_pipeListeners[key] copyItems];
    os_unfair_lock_unlock(&_lock);
    
    for (void (^listener)(id) in pipeListeners)
    {
        listener(next);
    }
}

@end
