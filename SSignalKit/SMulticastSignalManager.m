#import "SMulticastSignalManager.h"

#import "SSignal+Multicast.h"
#import "SSignal+SideEffects.h"

#import <libkern/OSAtomic.h>

@interface SMulticastSignalManager ()
{
    NSMutableDictionary *_signals;
    volatile OSSpinLock _lock;
}

@end

@implementation SMulticastSignalManager

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _signals = [[NSMutableDictionary alloc] init];
    }
    return self;
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
    signal = _signals[key];
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
                    [strongSelf->_signals removeObjectForKey:key];
                    OSSpinLockUnlock(&strongSelf->_lock);
                }
            }];
            _signals[key] = signal;
        }
    }
    OSSpinLockUnlock(&_lock);
    
    return signal;
}

@end
