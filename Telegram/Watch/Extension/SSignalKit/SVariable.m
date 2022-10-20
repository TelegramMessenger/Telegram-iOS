#import "SVariable.h"

#import <libkern/OSAtomic.h>

#import "SSignal.h"
#import "SBag.h"
#import "SBlockDisposable.h"
#import "SMetaDisposable.h"

@interface SVariable ()
{
    OSSpinLock _lock;
    id _value;
    bool _hasValue;
    SBag *_subscribers;
    SMetaDisposable *_disposable;
}

@end

@implementation SVariable

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _subscribers = [[SBag alloc] init];
        _disposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_disposable dispose];
}

- (SSignal *)signal
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        OSSpinLockLock(&self->_lock);
        id currentValue = _value;
        bool hasValue = _hasValue;
        NSInteger index = [self->_subscribers addItem:[^(id value)
        {
            [subscriber putNext:value];
        } copy]];
        OSSpinLockUnlock(&self->_lock);
        
        if (hasValue)
        {
            [subscriber putNext:currentValue];
        }
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            OSSpinLockLock(&self->_lock);
            [self->_subscribers removeItem:index];
            OSSpinLockUnlock(&self->_lock);
        }];
    }];
}

- (void)set:(SSignal *)signal
{
    OSSpinLockLock(&_lock);
    _hasValue = false;
    OSSpinLockUnlock(&_lock);
    
    __weak SVariable *weakSelf = self;
    [_disposable setDisposable:[signal startWithNext:^(id next)
    {
        __strong SVariable *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            NSArray *subscribers = nil;
            OSSpinLockLock(&strongSelf->_lock);
            strongSelf->_value = next;
            strongSelf->_hasValue = true;
            subscribers = [strongSelf->_subscribers copyItems];
            OSSpinLockUnlock(&strongSelf->_lock);
            
            for (void (^subscriber)(id) in subscribers)
            {
                subscriber(next);
            }
        }
    }]];
}

@end
