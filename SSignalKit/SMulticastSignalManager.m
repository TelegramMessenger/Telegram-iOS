#import "SMulticastSignalManager.h"

#import "SSignal+Multicast.h"
#import "SSignal+SideEffects.h"
#import "SBag.h"
#import "SMetaDisposable.h"

#import <libkern/OSAtomic.h>

@interface SMulticastSignalManager ()
{
    OSSpinLock _lock;
    NSMutableDictionary *_multicastSignals;
    NSMutableDictionary *_standaloneSignalDisposables;
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
    }
    return self;
}

- (void)dealloc
{
    NSArray *disposables = nil;
    OSSpinLockLock(&_lock);
    disposables = [_standaloneSignalDisposables allValues];
    OSSpinLockUnlock(&_lock);
    
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
    OSSpinLockLock(&_lock);
    signal = _multicastSignals[key];
    if (signal == nil)
    {
        __weak SMulticastSignalManager *weakSelf = self;
        if (producer)
            signal = producer();
        if (signal != nil)
        {
            signal = [[signal multicast] onDispose:^
            {
                __strong SMulticastSignalManager *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    OSSpinLockLock(&strongSelf->_lock);
                    [strongSelf->_multicastSignals removeObjectForKey:key];
                    OSSpinLockUnlock(&strongSelf->_lock);
                }
            }];
            _multicastSignals[key] = signal;
        }
    }
    OSSpinLockUnlock(&_lock);
    
    return signal;
}

- (void)startStandaloneSignalIfNotRunningForKey:(NSString *)key producer:(SSignal *(^)())producer
{
    if (key == nil)
        return;
    
    bool produce = false;
    OSSpinLockLock(&_lock);
    if (_standaloneSignalDisposables[key] == nil)
    {
        _standaloneSignalDisposables[key] = [[SMetaDisposable alloc] init];
        produce = true;
    }
    OSSpinLockUnlock(&_lock);
    
    if (produce)
    {
        __weak SMulticastSignalManager *weakSelf = self;
        id<SDisposable> disposable = [producer() startWithNext:nil error:^(__unused id error)
        {
            __strong SMulticastSignalManager *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                OSSpinLockLock(&strongSelf->_lock);
                [strongSelf->_standaloneSignalDisposables removeObjectForKey:key];
                OSSpinLockUnlock(&strongSelf->_lock);
            }
        } completed:^
        {
            __strong SMulticastSignalManager *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                OSSpinLockLock(&strongSelf->_lock);
                [strongSelf->_standaloneSignalDisposables removeObjectForKey:key];
                OSSpinLockUnlock(&strongSelf->_lock);
            }
        }];
        
        OSSpinLockLock(&_lock);
        [(SMetaDisposable *)_standaloneSignalDisposables[key] setDisposable:disposable];
        OSSpinLockUnlock(&_lock);
    }
}

@end
